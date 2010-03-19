/*
 * The contents of this file are subject to the Mozilla Public
 * License Version 1.1 (the "License"); you may not use this file
 * except in compliance with the License. You may obtain a copy of
 * the License at http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS
 * IS" basis, WITHOUT WARRANTY OF ANY KIND, either express or
 * implied. See the License for the specific language governing
 * rights and limitations under the License.
 *
 * The Original Code is MPEG4IP.
 *
 * The Initial Developer of the Original Code is Cisco Systems Inc.
 * Portions created by Cisco Systems Inc. are
 * Copyright (C) Cisco Systems Inc. 2004.  All Rights Reserved.
 *
 * Contributor(s):
 *           Bill May wmay@cisco.com
 *           Laurent Aimar (with much gratitude from the developers
 *                          for his work on ctts creation)
 */

//#define DEBUG_H264 0
//#define DEBUG_H264_READER 0

typedef struct h264_decode_t {
    uint8_t profile;
    uint8_t level;
    uint32_t chroma_format_idc;
    uint8_t residual_colour_transform_flag;
    uint32_t bit_depth_luma_minus8;
    uint32_t bit_depth_chroma_minus8;
    uint8_t qpprime_y_zero_transform_bypass_flag;
    uint8_t seq_scaling_matrix_present_flag;
    uint32_t log2_max_frame_num_minus4;
    uint32_t log2_max_pic_order_cnt_lsb_minus4;
    uint32_t pic_order_cnt_type;
    uint8_t frame_mbs_only_flag;
    uint8_t mb_adaptive_frame_field_flag;
    uint8_t direct_8x8_inference_flag;
    uint32_t frame_crop_left_offset;
    uint32_t frame_crop_right_offset;
    uint32_t frame_crop_top_offset;
    uint32_t frame_crop_bottom_offset;
    uint8_t aspect_ratio_info_present_flag;
    uint8_t aspect_ratio_idc;
    uint8_t pic_order_present_flag;
    uint8_t delta_pic_order_always_zero_flag;
    int32_t offset_for_non_ref_pic;
    int32_t offset_for_top_to_bottom_field;
    uint32_t pic_order_cnt_cycle_length;
    int16_t offset_for_ref_frame[256];
    
    uint8_t nal_ref_idc;
    uint8_t nal_unit_type;
    
    uint8_t field_pic_flag;
    uint8_t bottom_field_flag;
    uint32_t frame_num;
    uint32_t idr_pic_id;
    uint32_t pic_order_cnt_lsb;
    int32_t delta_pic_order_cnt_bottom;
    int32_t delta_pic_order_cnt[2];
    
    uint32_t pic_width, pic_height;
    uint32_t sar_width, sar_height;
    uint32_t slice_type;
    
    /* POC state */
    int32_t  pic_order_cnt;        /* can be < 0 */
    
    uint32_t  pic_order_cnt_msb;
    uint32_t  pic_order_cnt_msb_prev;
    uint32_t  pic_order_cnt_lsb_prev;
    uint32_t  frame_num_prev;
    int32_t  frame_num_offset;
    int32_t  frame_num_offset_prev;
    
    uint8_t NalHrdBpPresentFlag;
    uint8_t VclHrdBpPresentFlag;
    uint8_t CpbDpbDelaysPresentFlag;
    uint8_t pic_struct_present_flag;
    uint8_t cpb_removal_delay_length_minus1;
    uint8_t dpb_output_delay_length_minus1;
    uint8_t time_offset_length;
    uint32_t cpb_cnt_minus1;
    uint8_t initial_cpb_removal_delay_length_minus1;
} h264_decode_t;

typedef struct nal_reader_t {
    FILE *ifile;
	int pipeFD;
	int usePipe;
    uint8_t *buffer;
    uint32_t buffer_on;
    uint32_t buffer_size;
    uint32_t buffer_size_max;
} nal_reader_t;

#define H264_START_CODE 0x000001
#define H264_PREVENT_3_BYTE 0x000003

#define H264_PROFILE_BASELINE 66
#define H264_PROFILE_MAIN 77
#define H264_PROFILE_EXTENDED 88

#define H264_NAL_TYPE_NON_IDR_SLICE 1
#define H264_NAL_TYPE_DP_A_SLICE 2
#define H264_NAL_TYPE_DP_B_SLICE 3
#define H264_NAL_TYPE_DP_C_SLICE 0x4
#define H264_NAL_TYPE_IDR_SLICE 0x5
#define H264_NAL_TYPE_SEI 0x6
#define H264_NAL_TYPE_SEQ_PARAM 0x7
#define H264_NAL_TYPE_PIC_PARAM 0x8
#define H264_NAL_TYPE_ACCESS_UNIT 0x9
#define H264_NAL_TYPE_END_OF_SEQ 0xa
#define H264_NAL_TYPE_END_OF_STREAM 0xb
#define H264_NAL_TYPE_FILLER_DATA 0xc
#define H264_NAL_TYPE_SEQ_EXTENSION 0xd

#define H264_TYPE_P 0
#define H264_TYPE_B 1
#define H264_TYPE_I 2
#define H264_TYPE_SP 3
#define H264_TYPE_SI 4
#define H264_TYPE2_P 5
#define H264_TYPE2_B 6
#define H264_TYPE2_I 7
#define H264_TYPE2_SP 8
#define H264_TYPE2_SI 9

#define H264_TYPE_IS_P(t) ((t) == H264_TYPE_P || (t) == H264_TYPE2_P)
#define H264_TYPE_IS_B(t) ((t) == H264_TYPE_B || (t) == H264_TYPE2_B)
#define H264_TYPE_IS_I(t) ((t) == H264_TYPE_I || (t) == H264_TYPE2_I)
#define H264_TYPE_IS_SP(t) ((t) == H264_TYPE_SP || (t) == H264_TYPE2_SP)
#define H264_TYPE_IS_SI(t) ((t) == H264_TYPE_SI || (t) == H264_TYPE2_SI)

#define HAVE_SLICE_I 0x1
#define HAVE_SLICE_P 0x2
#define HAVE_SLICE_B 0x4
#define HAVE_SLICE_SI 0x8
#define HAVE_SLICE_SP 0x10
#define HAVE_ALL_SLICES 0x1f
#define HAVE_ALL_BUT_B_SLICES 0x1b

typedef struct
{
    struct
    {
        int size_min;
        int next;
        int cnt;
        int idx[17];
        int poc[17];
    } dpb;
    
    int cnt;
    int cnt_max;
    int *frame;
} h264_dpb_t;

static uint8_t exp_golomb_bits[256] = {
    8, 7, 6, 6, 5, 5, 5, 5, 4, 4, 4, 4, 4, 4, 4, 4, 3, 
    3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 2, 2, 
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 
    1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 
    0, 
};

