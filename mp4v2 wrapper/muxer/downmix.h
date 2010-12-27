/* $Id: downmix.h,v 1.51 2005/11/04 13:09:40 stebbins Exp $

   This file is part of the HandBrake source code.
   Homepage: <http://handbrake.fr/>.
   It may be used under the terms of the GNU General Public License. */

#ifndef DOWNMIX_H
#define DOWNMIX_H

/* Input Channel Layout */
/* define some masks, used to extract the various information from the HB_AMIXDOWN_XXXX values */
#define HB_INPUT_CH_LAYOUT_DISCRETE_FRONT_MASK  0x00F0000
#define HB_INPUT_CH_LAYOUT_DISCRETE_REAR_MASK   0x000F000
#define HB_INPUT_CH_LAYOUT_DISCRETE_LFE_MASK    0x0000F00
#define HB_INPUT_CH_LAYOUT_DISCRETE_NO_LFE_MASK 0xFFFF0FF
#define HB_INPUT_CH_LAYOUT_ENCODED_FRONT_MASK   0x00000F0
#define HB_INPUT_CH_LAYOUT_ENCODED_REAR_MASK    0x000000F
/* define the input channel layouts used to describe the channel layout of this audio */
#define HB_INPUT_CH_LAYOUT_MONO    0x0110010
#define HB_INPUT_CH_LAYOUT_STEREO  0x0220020
#define HB_INPUT_CH_LAYOUT_DOLBY   0x0320031
#define HB_INPUT_CH_LAYOUT_3F      0x0430030
#define HB_INPUT_CH_LAYOUT_2F1R    0x0521021
#define HB_INPUT_CH_LAYOUT_3F1R    0x0631031
#define HB_INPUT_CH_LAYOUT_2F2R    0x0722022
#define HB_INPUT_CH_LAYOUT_3F2R    0x0832032
#define HB_INPUT_CH_LAYOUT_4F2R    0x0942042
#define HB_INPUT_CH_LAYOUT_3F4R    0x0a34034
#define HB_INPUT_CH_LAYOUT_HAS_LFE 0x0000100

#define HB_AMIXDOWN_MONO                        0x01000001
// DCA_FORMAT of DCA_MONO                  = 0    = 0x000
// A52_FORMAT of A52_MONO                  = 1    = 0x01
// discrete channel count of 1
#define HB_AMIXDOWN_STEREO                      0x02002022
// DCA_FORMAT of DCA_STEREO                = 2    = 0x002
// A52_FORMAT of A52_STEREO                = 2    = 0x02
// discrete channel count of 2
#define HB_AMIXDOWN_DOLBY                       0x042070A2
// DCA_FORMAT of DCA_3F1R | DCA_OUT_DPLI   = 519  = 0x207
// A52_FORMAT of A52_DOLBY                 = 10   = 0x0A
// discrete channel count of 2
#define HB_AMIXDOWN_DOLBYPLII                   0x084094A2
// DCA_FORMAT of DCA_3F2R | DCA_OUT_DPLII  = 1033 = 0x409
// A52_FORMAT of A52_DOLBY | A52_USE_DPLII = 74   = 0x4A
// discrete channel count of 2
#define HB_AMIXDOWN_6CH                         0x10089176
// DCA_FORMAT of DCA_3F2R | DCA_LFE        = 137  = 0x089
// A52_FORMAT of A52_3F2R | A52_LFE        = 23   = 0x17
// discrete channel count of 6

typedef float hb_sample_t;

typedef struct
{
    int chan_map[10][2][8];
    int inv_chan_map[10][2][8];
} hb_chan_map_t;

typedef struct
{
    int            mode_in;
    int            mode_out;
    int            nchans_in;
    int            nchans_out;
    hb_sample_t    matrix[8][8];
    int            matrix_initialized;
    hb_sample_t    clev;
    hb_sample_t    slev;
    hb_sample_t    level;
    hb_sample_t    bias;
    hb_chan_map_t  map_in;
    hb_chan_map_t  map_out;

    int center;
    int left_surround;
    int right_surround;
    int rear_left_surround;
    int rear_right_surround;
} hb_downmix_t;

// For convenience, a map to convert smpte channel layout
// to QuickTime channel layout.
// Map Indicies are mode, lfe, channel respectively
extern hb_chan_map_t hb_smpte_chan_map;
extern hb_chan_map_t hb_ac3_chan_map;
extern hb_chan_map_t hb_qt_chan_map;

hb_downmix_t * hb_downmix_init(int layout, int mixdown);
void hb_downmix_close( hb_downmix_t **downmix );
int hb_downmix_set_mode( hb_downmix_t * downmix, int layout, int mixdown );
void hb_downmix_set_level( hb_downmix_t * downmix, hb_sample_t clev, hb_sample_t slev, hb_sample_t level );
void hb_downmix_adjust_level( hb_downmix_t * downmix );
void hb_downmix_set_bias( hb_downmix_t * downmix, hb_sample_t bias );
void hb_downmix_set_chan_map( 
    hb_downmix_t * downmix, 
    hb_chan_map_t * map_in, 
    hb_chan_map_t * map_out );
void hb_downmix( hb_downmix_t * downmix, hb_sample_t * dst, hb_sample_t * src, int nsamples);
void hb_layout_remap( 
    hb_chan_map_t * map_in, 
    hb_chan_map_t * map_out, 
    int layout, 
    hb_sample_t * samples, 
    int nsamples );
int hb_need_downmix( int layout, int mixdown );

#endif /* DOWNMIX_H */
