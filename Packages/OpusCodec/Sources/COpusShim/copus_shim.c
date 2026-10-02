#include "include/copus_shim.h"

int plic_opus_set_bitrate(OpusEncoder *encoder, opus_int32 bitrate) {
    return opus_encoder_ctl(encoder, OPUS_SET_BITRATE(bitrate));
}

int plic_opus_get_lookahead(OpusEncoder *encoder, opus_int32 *lookahead) {
    return opus_encoder_ctl(encoder, OPUS_GET_LOOKAHEAD(lookahead));
}
