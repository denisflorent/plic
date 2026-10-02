/* Non-variadic wrappers around opus_encoder_ctl.
 *
 * opus_encoder_ctl is a variadic macro-driven control interface, which Swift
 * cannot call at all. Each setting Plic needs gets a plain function here.
 */
#ifndef COPUS_SHIM_H
#define COPUS_SHIM_H

#include <opus.h>

/* Sets the target bitrate in bits per second. */
int plic_opus_set_bitrate(OpusEncoder *encoder, opus_int32 bitrate);

/* Reads the encoder's algorithmic delay, in samples at 48 kHz. The Ogg
 * container must declare this as pre-skip so players drop it on playback. */
int plic_opus_get_lookahead(OpusEncoder *encoder, opus_int32 *lookahead);

#endif
