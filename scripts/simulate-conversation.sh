#!/usr/bin/env bash
# simulate-conversation.sh — Continuously send AI-generated messages to the
# seeded Pebble homeserver, simulating live conversation.
#
# Requires the homeserver to already be running and seeded by
# seed-homeserver.sh. Uses `apfel` (local Apple Intelligence) to generate
# realistic conversational text for each user persona.
#
# Prerequisites: apfel, curl, jq
#
# Usage:
#   ./scripts/simulate-conversation.sh              # normal traffic (8-20s)
#   ./scripts/simulate-conversation.sh --high       # high traffic (2-6s)
#
# Press Ctrl+C to stop.

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SERVER_NAME="pebble.dev"
SERVER_URL="http://localhost:8008"
PASSWORD="pebble123"

# Traffic modes: delay range in seconds (min max)
MODE="normal"
DELAY_MIN=8
DELAY_MAX=20

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --high)
            MODE="high"
            DELAY_MIN=2
            DELAY_MAX=6
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--high]"
            echo ""
            echo "  --high    High traffic mode (2-6s between messages)"
            echo "  (default) Normal traffic mode (8-20s between messages)"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 2
            ;;
    esac
done

# Transaction ID counter
TXN_ID=0

# Message counter for summary
MSG_COUNT=0
START_TIME=$(date +%s)

# Associative arrays
declare -A TOKENS
declare -A DISPLAY_NAMES
declare -A PERSONAS
declare -A ROOM_IDS       # alias -> room_id
declare -A ROOM_NAMES     # room_id -> display name
declare -A ROOM_IS_DM     # room_id -> 1 if DM

# Users: username|display_name
USERS=(
    "morgan|Morgan Torres"
    "priya|Priya Sharma"
    "alex|Alex Kim"
    "jordan|Jordan Lee"
    "sam|Sam Nakamura"
    "riley|Riley Chen"
    "casey|Casey Brooks"
    "taylor|Taylor Okafor"
)

# Per-user personas for apfel system prompts
PERSONAS=(
    [morgan]="You are Morgan Torres, an engineering manager at a software company called Pebble. You are supportive, ask good questions, and keep the team aligned. You care about process, team health, and shipping quality work."
    [priya]="You are Priya Sharma, a senior backend engineer at Pebble. You are technical, precise, and helpful. You talk about APIs, databases, performance optimization, and system architecture."
    [alex]="You are Alex Kim, an iOS and macOS developer at Pebble. You are a SwiftUI expert and enthusiastic about native Apple development. You discuss UI implementation, performance, and platform APIs."
    [jordan]="You are Jordan Lee, the lead designer at Pebble. You are thoughtful about UX, accessibility, and visual design. You discuss mockups, design systems, typography, and user research."
    [sam]="You are Sam Nakamura, a DevOps engineer at Pebble. You are practical with dry humor. You talk about CI/CD, infrastructure, monitoring, and automation."
    [riley]="You are Riley Chen, a frontend web developer at Pebble. You are a CSS and JavaScript expert. You care about developer experience, web standards, and clean code."
    [casey]="You are Casey Brooks, the product manager at Pebble. You are data-driven and user-focused. You think about roadmap, priorities, user feedback, and metrics."
    [taylor]="You are Taylor Okafor, a QA engineer at Pebble. You are detail-oriented and thorough. You catch edge cases, write test plans, and care about quality."
)

# Room aliases the seed script creates (excluding spaces).
# Format: alias|weight|members (comma-separated)
# Weight: 3=high traffic, 1=normal, 0.5=low (DMs use integer 1 and get halved)
ROOM_DEFS=(
    "general|3|morgan,priya,alex,jordan,sam,riley,casey,taylor"
    "random|3|morgan,priya,alex,jordan,sam,riley,casey,taylor"
    "announcements|1|morgan,priya,alex,jordan,sam,riley,casey,taylor"
    "backend|1|priya,morgan,sam,alex"
    "ios|1|alex,priya,taylor,morgan"
    "frontend|1|riley,priya,taylor,morgan"
    "devops|1|sam,morgan,priya"
    "code-review|1|morgan,priya,alex,sam,riley,taylor"
    "design|1|jordan,casey,alex,morgan"
    "design-system|1|jordan,riley,alex"
    "product|1|casey,morgan,jordan"
    "roadmap|1|casey,morgan,priya,alex"
)

# Room topics for context (mirrors the seed script)
declare -A ROOM_TOPICS
ROOM_TOPICS=(
    [general]="Company-wide discussion"
    [random]="Watercooler, off-topic, and fun"
    [announcements]="Company news and updates"
    [backend]="Backend services, APIs, and infrastructure"
    [ios]="iOS and macOS development"
    [frontend]="Web frontend development"
    [devops]="CI/CD, deployment, and infrastructure"
    [code-review]="Pull requests, reviews, and merge discussion"
    [design]="UI/UX discussion and design reviews"
    [design-system]="Component library, tokens, and guidelines"
    [product]="Product planning and feature discussion"
    [roadmap]="Release planning and milestones"
)

# =============================================================================
# Helper Functions
# =============================================================================

next_txn() {
    TXN_ID=$((TXN_ID + 1))
    NEXT_TXN_RESULT="sim_txn_${TXN_ID}"
}

# Log in a user and store their access token.
# Usage: login_user <username>
login_user() {
    local username="$1"

    local response
    response=$(curl -s -X POST "${SERVER_URL}/_matrix/client/v3/login" \
        -H "Content-Type: application/json" \
        -d "{
            \"type\": \"m.login.password\",
            \"identifier\": {
                \"type\": \"m.id.user\",
                \"user\": \"${username}\"
            },
            \"password\": \"${PASSWORD}\"
        }")

    local token
    token=$(echo "$response" | jq -r '.access_token // empty')
    if [[ -z "$token" ]]; then
        echo "Error: Failed to log in as '${username}'."
        echo "Response: ${response}"
        exit 1
    fi

    TOKENS["$username"]="$token"
}

# Resolve a room alias to a room ID.
# Usage: resolve_alias <alias_localpart>
resolve_alias() {
    local alias="$1"
    local encoded_alias
    encoded_alias=$(printf '%s' "#${alias}:${SERVER_NAME}" | jq -sRr @uri)

    # Pick any logged-in user's token for the request
    local token="${TOKENS[morgan]}"

    local response
    response=$(curl -s -X GET "${SERVER_URL}/_matrix/client/v3/directory/room/${encoded_alias}" \
        -H "Authorization: Bearer ${token}")

    local room_id
    room_id=$(echo "$response" | jq -r '.room_id // empty')
    if [[ -z "$room_id" ]]; then
        echo "Warning: Could not resolve alias '#${alias}:${SERVER_NAME}'"
        echo "Response: ${response}"
        return 1
    fi

    ROOM_IDS["$alias"]="$room_id"
}

# Fetch the last N messages from a room as context for the AI.
# Returns a formatted string of "DisplayName: message" lines.
# Usage: fetch_context <room_id> <username> [limit]
fetch_context() {
    local room_id="$1"
    local username="$2"
    local limit="${3:-5}"
    local token="${TOKENS[$username]}"

    local response
    response=$(curl -s -X GET "${SERVER_URL}/_matrix/client/v3/rooms/${room_id}/messages?dir=b&limit=${limit}&filter=%7B%22types%22%3A%5B%22m.room.message%22%5D%7D" \
        -H "Authorization: Bearer ${token}")

    # Extract messages in reverse order (oldest first) and format them
    echo "$response" | jq -r '
        [.chunk // [] | .[] | select(.content.msgtype == "m.text") |
            {sender: .sender, body: .content.body}] |
        reverse | .[] |
        "\(.sender | split(":")[0] | ltrimstr("@")): \(.body)"
    ' 2>/dev/null || echo ""
}

# Generate a message using apfel.
# Usage: generate_message <username> <room_alias> <context>
generate_message() {
    local username="$1"
    local room_alias="$2"
    local context="$3"
    local persona="${PERSONAS[$username]}"
    local topic="${ROOM_TOPICS[$room_alias]:-General discussion}"

    local system_prompt="${persona}

You are chatting in the #${room_alias} channel (topic: ${topic}) on your company's internal chat. Write a single short chat message (1-3 sentences). Be natural and conversational — this is casual work chat, not a formal email. Do not use quotes around your message. Do not add any meta-commentary, labels, or prefixes. Just output the message text and nothing else."

    local user_prompt
    if [[ -n "$context" ]]; then
        user_prompt="Here are the recent messages in the channel:

${context}

Write your next message as a natural continuation of this conversation."
    else
        user_prompt="The channel has been quiet. Start a new topic of conversation relevant to the channel."
    fi

    local message
    message=$(apfel -q -s "$system_prompt" --max-tokens 150 --temperature 0.8 "$user_prompt" 2>/dev/null) || true

    # Strip any wrapping quotes the model might add
    message=$(echo "$message" | sed 's/^"//;s/"$//' | sed '/^$/d')

    if [[ -z "$message" ]]; then
        return 1
    fi

    echo "$message"
}

# Send a text message to a room.
# Usage: send_message <room_id> <username> <body>
send_message() {
    local room_id="$1"
    local username="$2"
    local body="$3"
    local token="${TOKENS[$username]}"
    next_txn
    local txn="$NEXT_TXN_RESULT"

    local escaped_body
    escaped_body=$(echo -n "$body" | jq -Rs '.')

    local response
    response=$(curl -s -X PUT "${SERVER_URL}/_matrix/client/v3/rooms/${room_id}/send/m.room.message/${txn}" \
        -H "Authorization: Bearer ${token}" \
        -H "Content-Type: application/json" \
        -d "{\"msgtype\": \"m.text\", \"body\": ${escaped_body}}")

    local event_id
    event_id=$(echo "$response" | jq -r '.event_id // empty')
    if [[ -z "$event_id" ]]; then
        echo "Warning: Failed to send message to room as '${username}'"
        return 1
    fi
}

# Pick a random integer in [min, max].
# Usage: rand_range <min> <max>
rand_range() {
    local min="$1"
    local max="$2"
    echo $(( RANDOM % (max - min + 1) + min ))
}

# Pick a weighted-random room alias. Rooms with higher weights are picked more
# often. Returns the alias via stdout.
pick_room() {
    # Build a flat array with entries repeated by weight.
    # Weight 3 = 3 entries, weight 1 = 1 entry.
    local entries=()
    for def in "${ROOM_DEFS[@]}"; do
        IFS='|' read -r alias weight _members <<< "$def"
        for (( i = 0; i < weight; i++ )); do
            entries+=("$alias")
        done
    done

    local idx=$(( RANDOM % ${#entries[@]} ))
    echo "${entries[$idx]}"
}

# Pick a random member of a room who is not the same as the excluded user.
# Usage: pick_member <room_alias> [exclude_username]
pick_member() {
    local room_alias="$1"
    local exclude="${2:-}"

    # Find the room definition
    local members_str=""
    for def in "${ROOM_DEFS[@]}"; do
        IFS='|' read -r alias _weight members <<< "$def"
        if [[ "$alias" == "$room_alias" ]]; then
            members_str="$members"
            break
        fi
    done

    if [[ -z "$members_str" ]]; then
        return 1
    fi

    # Split members into array
    IFS=',' read -ra members_arr <<< "$members_str"

    # Filter out excluded user if specified
    local candidates=()
    for m in "${members_arr[@]}"; do
        if [[ "$m" != "$exclude" ]]; then
            candidates+=("$m")
        fi
    done

    if [[ ${#candidates[@]} -eq 0 ]]; then
        candidates=("${members_arr[@]}")
    fi

    local idx=$(( RANDOM % ${#candidates[@]} ))
    echo "${candidates[$idx]}"
}

# =============================================================================
# Graceful Shutdown
# =============================================================================

cleanup() {
    local end_time=$(date +%s)
    local duration=$(( end_time - START_TIME ))
    local minutes=$(( duration / 60 ))
    local seconds=$(( duration % 60 ))

    echo ""
    echo ""
    echo "  Simulation stopped."
    echo "  Messages sent: ${MSG_COUNT}"
    echo "  Duration: ${minutes}m ${seconds}s"
    echo "  Mode: ${MODE}"
    echo ""
    exit 0
}

trap cleanup SIGINT SIGTERM

# =============================================================================
# Prerequisites Check
# =============================================================================

for cmd in apfel curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '${cmd}' is required but not installed."
        exit 1
    fi
done

# Check that the homeserver is reachable
if ! curl -s -o /dev/null -w "%{http_code}" "${SERVER_URL}/_matrix/client/versions" 2>/dev/null | grep -q "200"; then
    echo "Error: Homeserver at ${SERVER_URL} is not reachable."
    echo "Run seed-homeserver.sh first to start and seed the server."
    exit 1
fi

# =============================================================================
# Main Flow
# =============================================================================

echo ""
echo "  Pebble HQ — Live Conversation Simulator"
echo "  ========================================="
echo ""
echo "  Mode:   ${MODE} (${DELAY_MIN}-${DELAY_MAX}s between messages)"
echo "  Server: ${SERVER_URL}"
echo ""

# ---- Log in all users -------------------------------------------------------

printf "  Logging in users..."
for user_def in "${USERS[@]}"; do
    IFS='|' read -r username display_name <<< "$user_def"
    DISPLAY_NAMES["$username"]="$display_name"
    login_user "$username"
done
echo " done"

# ---- Resolve room aliases ----------------------------------------------------

printf "  Resolving rooms..."
for def in "${ROOM_DEFS[@]}"; do
    IFS='|' read -r alias _weight _members <<< "$def"
    resolve_alias "$alias" || true
done
echo " done"

# Verify we have at least some rooms
room_count=${#ROOM_IDS[@]}
if [[ $room_count -eq 0 ]]; then
    echo "Error: No rooms could be resolved. Is the homeserver seeded?"
    exit 1
fi

echo "  Resolved ${room_count} rooms."
echo ""
echo "  Simulating conversation... (Ctrl+C to stop)"
echo ""

# ---- Message loop ------------------------------------------------------------

while true; do
    # Pick a room
    room_alias=$(pick_room)
    room_id="${ROOM_IDS[$room_alias]:-}"

    if [[ -z "$room_id" ]]; then
        continue
    fi

    # Pick a random member of that room
    username=$(pick_member "$room_alias")

    # Fetch recent messages for context
    context=$(fetch_context "$room_id" "$username" 5)

    # Generate a message with apfel
    message=$(generate_message "$username" "$room_alias" "$context") || continue

    if [[ -z "$message" ]]; then
        continue
    fi

    # Send the message
    if send_message "$room_id" "$username" "$message"; then
        MSG_COUNT=$((MSG_COUNT + 1))
        timestamp=$(date "+%H:%M:%S")
        display_name="${DISPLAY_NAMES[$username]}"
        echo "  [${timestamp}] #${room_alias} (${display_name}): ${message}"
    fi

    # Random delay before next message
    delay=$(rand_range "$DELAY_MIN" "$DELAY_MAX")
    sleep "$delay"
done
