//
//  MP42H264FileImporter.m
//  Subler
//
//  Created by Damiano Galassi on 07/12/10.
//  Copyright 2010 Damiano Galassi All rights reserved.
//

#import "MP42H264Importer.h"
#import "lang.h"
#import "MP42File.h"
#include <sys/stat.h>

static const framerate_t framerates[] =
{ { 2398, 24000, 1001 },
    { 24, 600, 25 },
    { 25, 600, 24 },
    { 2997, 30000, 1001 },
    { 30, 600, 20 },
    { 50, 600, 12 },
    { 5994, 60000, 1001 },
    { 60, 600, 10 },
    { 0, 24000, 1001 } };

static const framerate_t framerates_thousand[] =
{ { 2398, 24000, 1001 },
	{ 2400, 600, 25 },
	{ 2500, 600, 24 },
	{ 2997, 30000, 1001 },
	{ 3000, 600, 20 },
    { 5000, 600, 12 },
	{ 5994, 60000, 1001 },
	{ 6000, 600, 10 },
	{ 0, 24000, 1001 } };

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

static const char*  ProgName = "Subler";
static int Verbosity = 0;

#include "mp4v2.h"
#include <assert.h>
#include <ctype.h> /* isdigit, isprint, isspace */
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <sys/types.h>
#include "mpeg4ip_bitstream.h"

uint32_t h264_ue (CBitstream *bs)
{
    uint32_t bits, read;
    int bits_left;
    uint8_t coded;
    bool done = false;
    uint32_t temp;
    bits = 0;
    // we want to read 8 bits at a time - if we don't have 8 bits, 
    // read what's left, and shift.  The exp_golomb_bits calc remains the
    // same.
    while (done == false) {
        bits_left = bs->bits_remain();
        if (bits_left < 8) {
            read = bs->PeekBits(bits_left) << (8 - bits_left);
            done = true;
        } else {
            read = bs->PeekBits(8);
            if (read == 0) {
                (void)bs->GetBits(8);
                bits += 8;
            } else {
                done = true;
            }
        }
    }
    coded = exp_golomb_bits[read];
    temp = bs->GetBits(coded);
    bits += coded;
    
    //  printf("ue - bits %d\n", bits);
    return bs->GetBits(bits + 1) - 1;
}

int32_t h264_se (CBitstream *bs) 
{
    uint32_t ret;
    ret = h264_ue(bs);
    if ((ret & 0x1) == 0) {
        ret >>= 1;
        int32_t temp = 0 - ret;
        return temp;
    } 
    return (ret + 1) >> 1;
}

static void h264_decode_annexb( uint8_t *dst, int *dstlen,
                               const uint8_t *src, const int srclen )
{
    uint8_t *dst_sav = dst;
    const uint8_t *end = &src[srclen];
    
    while (src < end)
    {
        if (src < end - 3 && src[0] == 0x00 && src[1] == 0x00 &&
            src[2] == 0x03)
        {
            *dst++ = 0x00;
            *dst++ = 0x00;
            
            src += 3;
            continue;
        }
        *dst++ = *src++;
    }
    
    *dstlen = dst - dst_sav;
}

extern "C" bool h264_is_start_code (const uint8_t *pBuf) 
{
    if (pBuf[0] == 0 && 
        pBuf[1] == 0 && 
        ((pBuf[2] == 1) ||
         ((pBuf[2] == 0) && pBuf[3] == 1))) {
            return true;
        }
    return false;
}

extern "C" uint32_t h264_find_next_start_code (const uint8_t *pBuf, 
                                               uint32_t bufLen)
{
    uint32_t val, temp;
    uint32_t offset;
    
    offset = 0;
    if (pBuf[0] == 0 && 
        pBuf[1] == 0 && 
        ((pBuf[2] == 1) ||
         ((pBuf[2] == 0) && pBuf[3] == 1))) {
            pBuf += 3;
            offset = 3;
        }
    val = 0xffffffff;
    while (offset < bufLen - 3) {
        val <<= 8;
        temp = val & 0xff000000;
        val &= 0x00ffffff;
        val |= *pBuf++;
        offset++;
        if (val == H264_START_CODE) {
            if (temp == 0) return offset - 4;
            return offset - 3;
        }
    }
    return 0;
}

extern "C" uint8_t h264_nal_unit_type (const uint8_t *buffer)
{
    uint32_t offset;
    if (buffer[2] == 1) offset = 3;
    else offset = 4;
    return buffer[offset] & 0x1f;
}

extern "C" int h264_nal_unit_type_is_slice (const uint8_t type)
{
    if (type >= H264_NAL_TYPE_NON_IDR_SLICE && 
        type <= H264_NAL_TYPE_IDR_SLICE) {
        return true;
    }
    return false;
}

/*
 * determine if the slice we decoded is a sync point
 */
extern "C" bool h264_slice_is_idr (h264_decode_t *dec) 
{
    if (dec->nal_unit_type != H264_NAL_TYPE_IDR_SLICE)
        return false;
    if (H264_TYPE_IS_I(dec->slice_type)) return true;
    if (H264_TYPE_IS_SI(dec->slice_type)) return true;
    return false;
}

extern "C" uint8_t h264_nal_ref_idc (const uint8_t *buffer)
{
    uint32_t offset;
    if (buffer[2] == 1) offset = 3;
    else offset = 4;
    return (buffer[offset] >> 5) & 0x3;
}

static void scaling_list (uint sizeOfScalingList, CBitstream *bs)
{
    uint lastScale = 8, nextScale = 8;
    uint j;
    
    for (j = 0; j < sizeOfScalingList; j++) {
        if (nextScale != 0) {
            int deltaScale = h264_se(bs);
            nextScale = (lastScale + deltaScale + 256) % 256;
        }
        if (nextScale == 0) {
            lastScale = lastScale;
        } else {
            lastScale = nextScale;
        }
    }
}

extern "C" void h264_hrd_parameters (h264_decode_t *dec, CBitstream *bs)
{
    uint32_t cpb_cnt;
    dec->cpb_cnt_minus1 = cpb_cnt = h264_ue(bs);
    uint32_t temp;
    printf("     cpb_cnt_minus1: %u\n", cpb_cnt);
    printf("     bit_rate_scale: %u\n", bs->GetBits(4));
    printf("     cpb_size_scale: %u\n", bs->GetBits(4));
    for (uint32_t ix = 0; ix <= cpb_cnt; ix++) {
        printf("      bit_rate_value_minus1[%u]: %u\n", ix, h264_ue(bs));
        printf("      cpb_size_value_minus1[%u]: %u\n", ix, h264_ue(bs));
        printf("      cbr_flag[%u]: %u\n", ix, bs->GetBits(1));
    }
    temp = dec->initial_cpb_removal_delay_length_minus1 = bs->GetBits(5);
    printf("     initial_cpb_removal_delay_length_minus1: %u\n", temp);
    
    dec->cpb_removal_delay_length_minus1 = temp = bs->GetBits(5);
    printf("     cpb_removal_delay_length_minus1: %u\n", temp);
    dec->dpb_output_delay_length_minus1 = temp = bs->GetBits(5);
    printf("     dpb_output_delay_length_minus1: %u\n", temp);
    dec->time_offset_length = temp = bs->GetBits(5);  
    printf("     time_offset_length: %u\n", temp);
}

extern "C" void h264_vui_parameters (h264_decode_t *dec, CBitstream *bs)
{
    //uint32_t temp;
    dec->aspect_ratio_info_present_flag = bs->GetBits(1);
    if (dec->aspect_ratio_info_present_flag) {
        dec->aspect_ratio_idc = bs->GetBits(8);
        if (dec->aspect_ratio_idc == 0xff) { // extended_SAR
            dec->sar_width = bs->GetBits(16);
            dec->sar_height = bs->GetBits(16);
        }
    }
    
#if 0
    temp = bs->GetBits(1);
    printf("    overscan_info_present_flag: %u\n", temp);
    if (temp) {
        printf("     overscan_appropriate_flag: %u\n", bs->GetBits(1));
    }
    temp = bs->GetBits(1);
    printf("    video_signal_info_present_flag: %u\n", temp);
    if (temp) {
        printf("     video_format: %u\n", bs->GetBits(3));
        printf("     video_full_range_flag: %u\n", bs->GetBits(1));
        temp = bs->GetBits(1);
        printf("     colour_description_present_flag: %u\n", temp);
        if (temp) {
            printf("      colour_primaries: %u\n", bs->GetBits(8));
            printf("      transfer_characteristics: %u\n", bs->GetBits(8));
            printf("      matrix_coefficients: %u\n", bs->GetBits(8));
        }
    }
    
    temp = bs->GetBits(1);
    printf("    chroma_loc_info_present_flag: %u\n", temp);
    if (temp) {
        printf("     chroma_sample_loc_type_top_field: %u\n", h264_ue(bs));
        printf("     chroma_sample_loc_type_bottom_field: %u\n", h264_ue(bs));
    }
    temp = bs->GetBits(1);
    printf("    timing_info_present_flag: %u\n", temp);
    if (temp) {
        printf("     num_units_in_tick: %u\n", bs->GetBits(32));
        printf("     time_scale: %u\n", bs->GetBits(32));
        printf("     fixed_frame_scale: %u\n", bs->GetBits(1));
    }
    temp = bs->GetBits(1);
    printf("    nal_hrd_parameters_present_flag: %u\n", temp);
    if (temp) {
        dec->NalHrdBpPresentFlag = 1;
        dec->CpbDpbDelaysPresentFlag = 1;
        h264_hrd_parameters(dec, bs);
    }
    uint32_t temp2;
    
    temp2 = bs->GetBits(1);
    printf("    vcl_hrd_parameters_present_flag: %u\n", temp2);
    if (temp2) {
        dec->VclHrdBpPresentFlag = 1;
        dec->CpbDpbDelaysPresentFlag = 1;
        h264_hrd_parameters(dec, bs);
    }
    if (temp || temp2) {
        printf("    low_delay_hrd_flag: %u\n", bs->GetBits(1));
    }
    dec->pic_struct_present_flag = temp = bs->GetBits(1);
    printf("    pic_struct_present_flag: %u\n", temp);
    temp = bs->GetBits(1);
    if (temp) {
        printf("    motion_vectors_over_pic_boundaries_flag: %u\n", bs->GetBits(1));
        printf("    max_bytes_per_pic_denom: %u\n", h264_ue(bs));
        printf("    max_bits_per_mb_denom: %u\n", h264_ue(bs));
        printf("    log2_max_mv_length_horizontal: %u\n", h264_ue(bs));
        printf("    log2_max_mv_length_vertical: %u\n", h264_ue(bs));
        printf("    num_reorder_frames: %u\n", h264_ue(bs));
        printf("     max_dec_frame_buffering: %u\n", h264_ue(bs));
    }
#endif
}

int h264_read_seq_info (const uint8_t *buffer, 
                        uint32_t buflen, 
                        h264_decode_t *dec)
{
    CBitstream bs;
    uint32_t header;
    uint8_t tmp[2048]; /* Should be enough for all SPS (we have at worst 13 bytes and 496 se/ue in frext) */
    int tmp_len;
    uint32_t dummy;
    
    if (buffer[2] == 1) header = 4;
    else header = 5;
    
    h264_decode_annexb( tmp, &tmp_len, buffer + header, MIN(buflen-header,2048) );
    bs.init(tmp, tmp_len * 8);
    
    //bs.set_verbose(true);
    try {
        dec->profile = bs.GetBits(8);
        dummy = bs.GetBits(1 + 1 + 1 + 1 + 4);
        dec->level = bs.GetBits(8);
        (void)h264_ue(&bs); // seq_parameter_set_id
        if (dec->profile == 100 || dec->profile == 110 ||
            dec->profile == 122 || dec->profile == 144) {
            dec->chroma_format_idc = h264_ue(&bs);
            if (dec->chroma_format_idc == 3) {
                dec->residual_colour_transform_flag = bs.GetBits(1);
            }
            dec->bit_depth_luma_minus8 = h264_ue(&bs);
            dec->bit_depth_chroma_minus8 = h264_ue(&bs);
            dec->qpprime_y_zero_transform_bypass_flag = bs.GetBits(1);
            dec->seq_scaling_matrix_present_flag = bs.GetBits(1);
            if (dec->seq_scaling_matrix_present_flag) {
                for (uint ix = 0; ix < 8; ix++) {
                    if (bs.GetBits(1)) {
                        scaling_list(ix < 6 ? 16 : 64, &bs);
                    }
                }
            }
        }
        dec->log2_max_frame_num_minus4 = h264_ue(&bs);
        dec->pic_order_cnt_type = h264_ue(&bs);
        if (dec->pic_order_cnt_type == 0) {
            dec->log2_max_pic_order_cnt_lsb_minus4 = h264_ue(&bs);
        } else if (dec->pic_order_cnt_type == 1) {
            dec->delta_pic_order_always_zero_flag = bs.GetBits(1);
            dec->offset_for_non_ref_pic = h264_se(&bs); // offset_for_non_ref_pic
            dec->offset_for_top_to_bottom_field = h264_se(&bs); // offset_for_top_to_bottom_field
            dec->pic_order_cnt_cycle_length = h264_ue(&bs); // poc_cycle_length
            for (uint32_t ix = 0; ix < dec->pic_order_cnt_cycle_length; ix++) {
                dec->offset_for_ref_frame[MIN(ix,255)] = h264_se(&bs); // offset for ref fram -
            }
        }
        dummy = h264_ue(&bs); // num_ref_frames
        dummy = bs.GetBits(1); // gaps_in_frame_num_value_allowed_flag
        uint32_t PicWidthInMbs = h264_ue(&bs) + 1;
        dec->pic_width = PicWidthInMbs * 16;
        uint32_t PicHeightInMapUnits = h264_ue(&bs) + 1;
        
        dec->frame_mbs_only_flag = bs.GetBits(1);
        dec->pic_height = 
        (2 - dec->frame_mbs_only_flag) * PicHeightInMapUnits * 16;
        
        if (!dec->frame_mbs_only_flag) {
            dec->mb_adaptive_frame_field_flag = bs.GetBits(1);
        }
        dec->direct_8x8_inference_flag = bs.GetBits(1);
        dummy = bs.GetBits(1);
        if (dummy) {
            dec->frame_crop_left_offset = h264_ue(&bs);
            dec->frame_crop_right_offset = h264_ue(&bs);
            dec->frame_crop_top_offset = h264_ue(&bs);
            dec->frame_crop_bottom_offset = h264_ue(&bs);
            
            dec->pic_width -= 2*dec->frame_crop_right_offset;
            if (dec->frame_mbs_only_flag)
                dec->pic_height -= 2*dec->frame_crop_bottom_offset;
            else
                dec->pic_height -= 4*dec->frame_crop_bottom_offset;
        }
        dummy = bs.GetBits(1);
        if (dummy) {
            h264_vui_parameters(dec, &bs);
        }
        
    } catch (...) {
        return -1;
    }
    return 0;
}
extern "C" int h264_find_slice_type (const uint8_t *buffer, 
                                     uint32_t buflen,
                                     uint8_t *slice_type, 
                                     bool noheader)
{
    uint32_t header;
    uint32_t dummy;
    if (noheader) header = 1;
    else {
        if (buffer[2] == 1) header = 4;
        else header = 5;
    }
    CBitstream bs;
    bs.init(buffer + header, (buflen - header) * 8);
    try {
        dummy = h264_ue(&bs); // first_mb_in_slice
        *slice_type = h264_ue(&bs); // slice type
    } catch (...) {
        return -1;
    }
    return 0;
}

extern "C" int h264_read_slice_info (const uint8_t *buffer, 
                                     uint32_t buflen, 
                                     h264_decode_t *dec)
{
    uint32_t header;
    uint8_t tmp[512]; /* Enough for the begining of the slice header */
    int tmp_len;
    uint32_t temp;
    
    if (buffer[2] == 1) header = 4;
    else header = 5;
    CBitstream bs;
    
    h264_decode_annexb( tmp, &tmp_len, buffer + header, MIN(buflen-header,512) );
    bs.init(tmp, tmp_len * 8);
    try {
        dec->field_pic_flag = 0;
        dec->bottom_field_flag = 0;
        dec->delta_pic_order_cnt[0] = 0;
        dec->delta_pic_order_cnt[1] = 0;
        temp = h264_ue(&bs); // first_mb_in_slice
        dec->slice_type = h264_ue(&bs); // slice type
        temp = h264_ue(&bs); // pic_parameter_set
        dec->frame_num = bs.GetBits(dec->log2_max_frame_num_minus4 + 4);
        if (!dec->frame_mbs_only_flag) {
            dec->field_pic_flag = bs.GetBits(1);
            if (dec->field_pic_flag) {
                dec->bottom_field_flag = bs.GetBits(1);
            }
        }
        if (dec->nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {
            dec->idr_pic_id = h264_ue(&bs);
        }
        switch (dec->pic_order_cnt_type) {
            case 0:
                dec->pic_order_cnt_lsb = bs.GetBits(dec->log2_max_pic_order_cnt_lsb_minus4 + 4);
                if (dec->pic_order_present_flag && !dec->field_pic_flag) {
                    dec->delta_pic_order_cnt_bottom = h264_se(&bs);
                }
                break;
            case 1:
                if (!dec->delta_pic_order_always_zero_flag) {
                    dec->delta_pic_order_cnt[0] = h264_se(&bs);
                }
                if (dec->pic_order_present_flag && !dec->field_pic_flag) {
                    dec->delta_pic_order_cnt[1] = h264_se(&bs);
                }
                break;
        }
        
    } catch (...) {
        return -1;
    }
    return 0;
}

static void h264_compute_poc( h264_decode_t *dec ) {
    const int max_frame_num = 1 << (dec->log2_max_frame_num_minus4 + 4);
    int field_poc[2] = {0,0};
    enum {
        H264_PICTURE_FRAME,
        H264_PICTURE_FIELD_TOP,
        H264_PICTURE_FIELD_BOTTOM,
    } pic_type;
    
    /* FIXME FIXME it doesn't handle the case where there is a MMCO == 5
     * (MMCO 5 "emulates" an idr) */
    
    /* picture type */
    if (dec->frame_mbs_only_flag || !dec->field_pic_flag)
        pic_type = H264_PICTURE_FRAME;
    else if (dec->bottom_field_flag)
        pic_type = H264_PICTURE_FIELD_BOTTOM;
    else
        pic_type = H264_PICTURE_FIELD_TOP;
    
    /* frame_num_offset */
    if (dec->nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {
        dec->pic_order_cnt_lsb_prev = 0;
        dec->pic_order_cnt_msb_prev = 0;
        dec->frame_num_offset = 0;
    } else {
        if (dec->frame_num < dec->frame_num_prev)
            dec->frame_num_offset = dec->frame_num_offset_prev + max_frame_num;
        else
            dec->frame_num_offset = dec->frame_num_offset_prev;
    }
    
    /* */
    if(dec->pic_order_cnt_type == 0) {
        const unsigned int max_poc_lsb = 1 << (dec->log2_max_pic_order_cnt_lsb_minus4 + 4);
        
        if (dec->pic_order_cnt_lsb < dec->pic_order_cnt_lsb_prev &&
            dec->pic_order_cnt_lsb_prev - dec->pic_order_cnt_lsb >= max_poc_lsb / 2)
            dec->pic_order_cnt_msb = dec->pic_order_cnt_msb_prev + max_poc_lsb;
        else if (dec->pic_order_cnt_lsb > dec->pic_order_cnt_lsb_prev &&
                 dec->pic_order_cnt_lsb - dec->pic_order_cnt_lsb_prev > max_poc_lsb / 2)
            dec->pic_order_cnt_msb = dec->pic_order_cnt_msb_prev - max_poc_lsb;
        else
            dec->pic_order_cnt_msb = dec->pic_order_cnt_msb_prev;
        
        field_poc[0] = dec->pic_order_cnt_msb + dec->pic_order_cnt_lsb;
        field_poc[1] = field_poc[0];
        if (pic_type == H264_PICTURE_FRAME)
            field_poc[1] += dec->delta_pic_order_cnt_bottom;
        
    } else if (dec->pic_order_cnt_type == 1) {
        int abs_frame_num, expected_delta_per_poc_cycle, expected_poc;
        
        if (dec->pic_order_cnt_cycle_length != 0)
            abs_frame_num = dec->frame_num_offset + dec->frame_num;
        else
            abs_frame_num = 0;
        
        if (dec->nal_ref_idc == 0 && abs_frame_num > 0)
            abs_frame_num--;
        
        expected_delta_per_poc_cycle = 0;
        for (int i = 0; i < (int)dec->pic_order_cnt_cycle_length; i++ )
            expected_delta_per_poc_cycle += dec->offset_for_ref_frame[i];
        
        if (abs_frame_num > 0) {
            const int poc_cycle_cnt = ( abs_frame_num - 1 ) / dec->pic_order_cnt_cycle_length;
            const int frame_num_in_poc_cycle = ( abs_frame_num - 1 ) % dec->pic_order_cnt_cycle_length;
            
            expected_poc = poc_cycle_cnt * expected_delta_per_poc_cycle;
            for (int i = 0; i <= frame_num_in_poc_cycle; i++)
                expected_poc += dec->offset_for_ref_frame[i];
        } else {
            expected_poc = 0;
        }
        
        if (dec->nal_ref_idc == 0)
            expected_poc += dec->offset_for_non_ref_pic;
        
        field_poc[0] = expected_poc + dec->delta_pic_order_cnt[0];
        field_poc[1] = field_poc[0] + dec->offset_for_top_to_bottom_field;
        
        if (pic_type == H264_PICTURE_FRAME)
            field_poc[1] += dec->delta_pic_order_cnt[1];
        
    } else if (dec->pic_order_cnt_type == 2) {
        int poc;
        if (dec->nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {
            poc = 0;
        } else {
            const int abs_frame_num = dec->frame_num_offset + dec->frame_num;
            if (dec->nal_ref_idc != 0)
                poc = 2 * abs_frame_num;
            else
                poc = 2 * abs_frame_num - 1;
        }
        field_poc[0] = poc;
        field_poc[1] = poc;
    }
    
    /* */
    if (pic_type == H264_PICTURE_FRAME)
        dec->pic_order_cnt = MIN(field_poc[0], field_poc[1] );
    else if (pic_type == H264_PICTURE_FIELD_TOP)
        dec->pic_order_cnt = field_poc[0];
    else
        dec->pic_order_cnt = field_poc[1];
}


extern "C" int h264_detect_boundary (const uint8_t *buffer, 
                                     uint32_t buflen, 
                                     h264_decode_t *decode)
{
    uint8_t temp;
    h264_decode_t new_decode;
    int ret;
    int slice = 0;
    memcpy(&new_decode, decode, sizeof(new_decode));
    
    temp = new_decode.nal_unit_type = h264_nal_unit_type(buffer);
    new_decode.nal_ref_idc = h264_nal_ref_idc(buffer);
    ret = 0;
    switch (temp) {
        case H264_NAL_TYPE_ACCESS_UNIT:
        case H264_NAL_TYPE_END_OF_SEQ:
        case H264_NAL_TYPE_END_OF_STREAM:
#ifdef BOUND_VERBOSE
            printf("nal type %d\n", temp);
#endif
            ret = 1;
            break;
        case H264_NAL_TYPE_NON_IDR_SLICE:
        case H264_NAL_TYPE_DP_A_SLICE:
        case H264_NAL_TYPE_DP_B_SLICE:
        case H264_NAL_TYPE_DP_C_SLICE:
        case H264_NAL_TYPE_IDR_SLICE:
            slice = 1;
            // slice buffer - read the info into the new_decode, and compare.
            if (h264_read_slice_info(buffer, buflen, &new_decode) < 0) {
                // need more memory
                return -1;
            }
            if (decode->nal_unit_type > H264_NAL_TYPE_IDR_SLICE || 
                decode->nal_unit_type < H264_NAL_TYPE_NON_IDR_SLICE) {
                break;
            }
            if (decode->frame_num != new_decode.frame_num) {
#ifdef BOUND_VERBOSE
                printf("frame num values different %u %u\n", decode->frame_num, 
                       new_decode.frame_num);
#endif
                ret = 1;
                break;
            }
            if (decode->field_pic_flag != new_decode.field_pic_flag) {
                ret = 1;
#ifdef BOUND_VERBOSE
                printf("field pic values different\n");
#endif
                break;
            }
            if (decode->nal_ref_idc != new_decode.nal_ref_idc &&
                (decode->nal_ref_idc == 0 ||
                 new_decode.nal_ref_idc == 0)) {
#ifdef BOUND_VERBOSE
                    printf("nal ref idc values differ\n");
#endif
                    ret = 1;
                    break;
                }
            if (decode->frame_num == new_decode.frame_num &&
                decode->pic_order_cnt_type == new_decode.pic_order_cnt_type) {
                if (decode->pic_order_cnt_type == 0) {
                    if (decode->pic_order_cnt_lsb != new_decode.pic_order_cnt_lsb) {
#ifdef BOUND_VERBOSE
                        printf("pic order 1\n");
#endif
                        ret = 1;
                        break;
                    }
                    if (decode->delta_pic_order_cnt_bottom != new_decode.delta_pic_order_cnt_bottom) {
                        ret = 1;
#ifdef BOUND_VERBOSE
                        printf("delta pic order cnt bottom 1\n");
#endif
                        break;
                    }
                } else if (decode->pic_order_cnt_type == 1) {
                    if (decode->delta_pic_order_cnt[0] != new_decode.delta_pic_order_cnt[0]) {
                        ret =1;
#ifdef BOUND_VERBOSE
                        printf("delta pic order cnt [0]\n");
#endif
                        break;
                    }
                    if (decode->delta_pic_order_cnt[1] != new_decode.delta_pic_order_cnt[1]) {
                        ret = 1;
#ifdef BOUND_VERBOSE
                        printf("delta pic order cnt [1]\n");
#endif
                        break;
                        
                    }
                }
            }
            if (decode->nal_unit_type == H264_NAL_TYPE_IDR_SLICE &&
                new_decode.nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {
                if (decode->idr_pic_id != new_decode.idr_pic_id) {
#ifdef BOUND_VERBOSE
                    printf("idr_pic id\n");
#endif
                    
                    ret = 1;
                    break;
                }
            }
            break;
        case H264_NAL_TYPE_SEQ_PARAM:
            if (h264_read_seq_info(buffer, buflen, &new_decode) < 0) {
                return -1;
            }
            // fall through
        default:
            if (decode->nal_unit_type <= H264_NAL_TYPE_IDR_SLICE) ret = 1;
            else ret = 0;
    } 
    
    /* save _prev values */
    if (ret)
    {
        new_decode.frame_num_offset_prev = decode->frame_num_offset;
        if (decode->pic_order_cnt_type != 2 || decode->nal_ref_idc != 0)
            new_decode.frame_num_prev = decode->frame_num;
        if (decode->nal_ref_idc != 0)
        {
            new_decode.pic_order_cnt_lsb_prev = decode->pic_order_cnt_lsb;
            new_decode.pic_order_cnt_msb_prev = decode->pic_order_cnt_msb;
        }
    }
    
    if( slice ) {  // XXX we compute poc for every slice in a picture (but it's not needed)
        h264_compute_poc( &new_decode );
    }
    
    
    // other types (6, 7, 8, 
#ifdef BOUND_VERBOSE
    if (ret == 0) {
        printf("no change\n");
    }
#endif
    
    memcpy(decode, &new_decode, sizeof(*decode));
    return ret;
}

uint32_t h264_read_sei_value (const uint8_t *buffer, uint32_t *size) 
{
    uint32_t ret = 0;
    *size = 1;
    while (buffer[*size] == 0xff) {
        ret += 255;
        *size = *size + 1;
    }
    ret += *buffer;
    return ret;
}

extern "C" const char *h264_get_frame_type (h264_decode_t *dec)
{
    if (dec->nal_unit_type == H264_NAL_TYPE_IDR_SLICE) {
        if (H264_TYPE_IS_I(dec->slice_type)) return "IDR";
        if (H264_TYPE_IS_SI(dec->slice_type)) return "IDR";
    }
    else {
        if (H264_TYPE_IS_P(dec->slice_type)) return "P";
        if (H264_TYPE_IS_B(dec->slice_type)) 
            if (dec->nal_ref_idc)
                return "BREF";
            else
                return "B";
        if (H264_TYPE_IS_I(dec->slice_type)) return "I";
        if (H264_TYPE_IS_SI(dec->slice_type)) return "SI";
        if (H264_TYPE_IS_SP(dec->slice_type)) return "SP";
    }
    return "UNK";
}

extern "C" uint32_t h264_get_frame_dependency (h264_decode_t *dec)
{
    uint32_t dflags = 0;
    
    if (dec->nal_ref_idc)
        dflags |= MP4_SDT_HAS_DEPENDENTS;
    else
        dflags |= MP4_SDT_HAS_NO_DEPENDENTS; /* disposable */
    
    if (dec->nal_unit_type != H264_NAL_TYPE_IDR_SLICE) {
        if (H264_TYPE_IS_P(dec->slice_type)) dflags |= MP4_SDT_EARLIER_DISPLAY_TIMES_ALLOWED;
        if (H264_TYPE_IS_I(dec->slice_type)) dflags |= MP4_SDT_EARLIER_DISPLAY_TIMES_ALLOWED;;
    }
    
    return dflags;
}

extern "C" const char *h264_get_slice_name (const uint8_t slice_type)
{
    if (H264_TYPE_IS_P(slice_type)) return "P";  
    if (H264_TYPE_IS_B(slice_type)) return "B";  
    if (H264_TYPE_IS_I(slice_type)) return "I";
    if (H264_TYPE_IS_SI(slice_type)) return "SI";
    if (H264_TYPE_IS_SP(slice_type)) return "SP";
    return "UNK";
}

extern "C" bool h264_access_unit_is_sync (const uint8_t *pNal, uint32_t len)
{
    uint8_t nal_type;
    h264_decode_t dec;
    uint32_t offset;
    do {
        nal_type = h264_nal_unit_type(pNal);
        if (nal_type == H264_NAL_TYPE_SEQ_PARAM) return true;
        if (nal_type == H264_NAL_TYPE_PIC_PARAM) return true;
        if (nal_type == H264_NAL_TYPE_IDR_SLICE) return true;
        if (h264_nal_unit_type_is_slice(nal_type)) {
            if (h264_read_slice_info(pNal, len, &dec) < 0) return false;
            if (H264_TYPE_IS_I(dec.slice_type) ||
                H264_TYPE_IS_SI(dec.slice_type)) return true;
            return false;
        }
        offset = h264_find_next_start_code(pNal, len);
        if (offset == 0 || offset > len) return false;
        pNal += offset;
        len -= offset;
    } while (len > 0);
    return false;
}

extern "C" char *h264_get_profile_level_string (const uint8_t profile, 
                                                const uint8_t level)
{
    const char *pro;
    char profileb[20], levelb[20];
    if (profile == 66) {
        pro = "Baseline";
    } else if (profile == 77) {
        pro = "Main";
    } else if (profile == 88) {
        pro =  "Extended";
    } else if (profile == 100) {
        pro = "High";
    } else if (profile == 110) {
        pro =  "High 10";
    } else if (profile == 122) {
        pro = "High 4:2:2";
    } else if (profile == 144) {
        pro = "High 4:4:4";
    } else if (profile == 244) {
        pro = "High 4:4:4 Predictive";
    } else {
        snprintf(profileb, sizeof(profileb), "Unknown Profile %x", profile);
        pro = profileb;
    } 
    switch (level) {
        case 10: case 20: case 30: case 40: case 50:
            snprintf(levelb, sizeof(levelb), "%u", level / 10);
            break;
        case 11: case 12: case 13:
        case 21: case 22:
        case 31: case 32:
        case 41: case 42:
        case 51:
            snprintf(levelb, sizeof(levelb), "%u.%u", level / 10, level % 10);
            break;
        default:
            snprintf(levelb, sizeof(levelb), "unknown level %x", level);
            break;
    }
    uint len =
    1 + strlen("H.264 @") + strlen(pro) + strlen(levelb);
    char *typebuffer = 
    (char *)malloc(len);
    if (typebuffer == NULL) return NULL;
    
    snprintf(typebuffer, len,  "H.264 %s@%s", pro, levelb);
    return typebuffer;
}


void DpbInit( h264_dpb_t *p )
{
    p->dpb.cnt = 0;
    p->dpb.next = 0;
    p->dpb.size_min = 0;
    
    p->cnt = 0;
    p->cnt_max = 0;
    p->frame = NULL;
}
void DpbClean( h264_dpb_t *p )
{
    free( p->frame );
}
static void DpbUpdate( h264_dpb_t *p, int is_forced )
{
    int i;
    int pos;
    
    if (!is_forced && p->dpb.cnt < 16)
        return;
    
    /* find the lowest poc */
    pos = 0;
    for (i = 1; i < p->dpb.cnt; i++)
    {
        if (p->dpb.poc[i] < p->dpb.poc[pos])
            pos = i;
    }
    //fprintf( stderr, "lowest=%d\n", pos );
    
    /* save the idx */
    if (p->dpb.idx[pos] >= p->cnt_max)
    {
        int inc = 1000 + (p->dpb.idx[pos]-p->cnt_max);
        p->cnt_max += inc;
        p->frame = (int*)realloc( p->frame, sizeof(int)*p->cnt_max );
        for (i=0;i<inc;i++)
            p->frame[p->cnt_max-inc+i] = -1; /* To detect errors latter */
    }
    p->frame[p->dpb.idx[pos]] = p->cnt++;
    
    /* Update the dpb minimal size */
    if (pos > p->dpb.size_min)
        p->dpb.size_min = pos;
    
    /* update dpb */
    for (i = pos; i < p->dpb.cnt-1; i++)
    {
        p->dpb.idx[i] = p->dpb.idx[i+1];
        p->dpb.poc[i] = p->dpb.poc[i+1];
    }
    p->dpb.cnt--;
}

void DpbFlush( h264_dpb_t *p )
{
    while (p->dpb.cnt > 0)
        DpbUpdate( p, true );
}

void DpbAdd( h264_dpb_t *p, int poc, int is_idr )
{
    if (is_idr)
        DpbFlush( p );
    
    p->dpb.idx[p->dpb.cnt] = p->dpb.next;
    p->dpb.poc[p->dpb.cnt] = poc;
    p->dpb.cnt++;
    p->dpb.next++;
    
    DpbUpdate( p, false );
}

int DpbFrameOffset( h264_dpb_t *p, int idx )
{
    if (idx >= p->cnt)
        return 0;
    if (p->frame[idx] < 0)
        return p->dpb.size_min; /* We have an error (probably broken/truncated bitstream) */
    
    return p->dpb.size_min + p->frame[idx] - idx;
}


static bool remove_unused_sei_messages (nal_reader_t *nal,
                                        uint32_t header_size)
{
    uint32_t buffer_on = header_size;
    buffer_on++; // increment past SEI message header
    
    while (buffer_on < nal->buffer_on) {
        uint32_t payload_type, payload_size, start, size;
        if (nal->buffer[buffer_on] == 0x80) {
            // rbsp_trailing_bits
            return true;
        }
        if (nal->buffer_on - buffer_on <= 2) {
            //fprintf(stderr, "extra bytes after SEI message\n");
#if 0
            memset(nal->buffer + buffer_on, 0,
                   nal->buffer_on - buffer_on); 
            nal->buffer_on = buffer_on;
#endif
            
            return true;
        }
        start = buffer_on;
        payload_type = h264_read_sei_value(nal->buffer + buffer_on,
                                           &size);
#ifdef DEBUG_H264
        printf("sei type %d size %d on %d\n", payload_type, 
               size, buffer_on);
#endif
        buffer_on += size;
        payload_size = h264_read_sei_value(nal->buffer + buffer_on,
                                           &size);
        buffer_on += size + payload_size;
#ifdef DEBUG_H264
        printf("sei size %d size %d on %d nal %d\n",
               payload_size, size, buffer_on, nal->buffer_on);
#endif
        if (buffer_on > nal->buffer_on) {
            fprintf(stderr, "Error decoding sei message\n");
            return false;
        }
        switch (payload_type) {
            case 3:
            case 10:
            case 11:
            case 12:
                memmove(nal->buffer + start,
                        nal->buffer + buffer_on, 
                        nal->buffer_size - buffer_on);
                nal->buffer_size -= buffer_on - start;
                nal->buffer_on -= buffer_on - start;
                buffer_on = start;
                break;
        }
    }
    if (nal->buffer_on == header_size) return false;
    return true;
}

static bool RefreshReader (nal_reader_t *nal,
                           uint32_t nal_start)
{
    uint32_t bytes_left;
    uint32_t bytes_read;
#ifdef DEBUG_H264_READER
    printf("refresh - start %u buffer on %u size %u\n", 
           nal_start, nal->buffer_on, nal->buffer_size);
#endif
    if (nal_start != 0) {
        if (nal_start > nal->buffer_size) {
#ifdef DEBUG_H264
            printf("nal start is greater than buffer size\n");
#endif
            nal->buffer_on = 0;
        } else {
            bytes_left = nal->buffer_size - nal_start;
            if (bytes_left > 0) {
                memmove(nal->buffer, 
                        nal->buffer + nal_start,
                        bytes_left);
                nal->buffer_on -= nal_start;
#ifdef DEBUG_H264_READER
                printf("move %u new on is %u\n", bytes_left, nal->buffer_on);
#endif
            } else {
                nal->buffer_on = 0;
            }
            nal->buffer_size = bytes_left;
        }
    } else {
        if (feof(nal->ifile)) {
            return false;
        }
        nal->buffer_size_max += 4096 * 4;
        nal->buffer = (uint8_t *)realloc(nal->buffer, nal->buffer_size_max);
    }
    bytes_read = fread(nal->buffer + nal->buffer_size,
                       1,
                       nal->buffer_size_max - nal->buffer_size,
                       nal->ifile);
    if (bytes_read == 0) return false;
#ifdef DEBUG_H264_READER
    printf("read %u of %u\n", bytes_read, 
           nal->buffer_size_max - nal->buffer_size);
#endif
    nal->buffer_size += bytes_read;
    return true;
}

static bool LoadNal (nal_reader_t *nal)
{
    if (nal->buffer_on != 0 || nal->buffer_size == 0) {
        if (RefreshReader(nal, nal->buffer_on) == false) {
#ifdef DEBUG_H264
            printf("refresh returned 0 - buffer on is %u, size %u\n",
                   nal->buffer_on, nal->buffer_size);
#endif
            if (nal->buffer_on >= nal->buffer_size) return false;
            // continue
        }
    }
    // find start code
    uint32_t start;
    if (h264_is_start_code(nal->buffer) == false) {
        start = h264_find_next_start_code(nal->buffer,
                                          nal->buffer_size);
        RefreshReader(nal, start);
    }
    while ((start = h264_find_next_start_code(nal->buffer + 4,
                                              nal->buffer_size - 4)) == 0) {
        if (RefreshReader(nal, 0) == false) {
            // end of file - use the last NAL
            nal->buffer_on = nal->buffer_size;
            return true;
        }
    }
    nal->buffer_on = start + 4;
    return true;
}

NSData* H264Info(const char *filePath, uint32_t *pic_width, uint32_t *pic_height, uint8_t *profile, uint8_t *level)
{
    // track configuration info
    NSMutableData * avcCData = [[NSMutableData alloc] init];
    uint8_t AVCProfileIndication = 0;
    uint8_t profile_compat = 0;
    uint8_t AVCLevelIndication = 0;
    uint8_t configurationVersion = 0;
    uint8_t sampleLenFieldSizeMinusOne = 3;

    bool have_seq = false;
    bool have_pic = false;
    uint8_t nal_type;
    nal_reader_t nal;
    h264_decode_t h264_dec;
    FILE *inFile;
    
    inFile = fopen(filePath, "r");
    if (inFile == NULL) return 0;
    
    memset(&nal, 0, sizeof(nal));
    nal.ifile = inFile;
    
    while (have_seq == false || have_pic == false) {
        if (LoadNal(&nal) == false) {
            // fprintf(stderr, "%s: Could not find sequence header\n", ProgName);
            fclose(inFile);
            return 0;
        }
        uint32_t header_size = nal.buffer[2] == 1 ? 3 : 4;

        nal_type = h264_nal_unit_type(nal.buffer);
        if (nal_type == H264_NAL_TYPE_SEQ_PARAM && !have_seq) {
            have_seq = true;
            uint32_t offset;
            if (nal.buffer[2] == 1) offset = 3;
            else offset = 4;

            AVCProfileIndication = nal.buffer[offset + 1];
            profile_compat = nal.buffer[offset + 2];
            AVCLevelIndication = nal.buffer[offset + 3];

            [avcCData appendBytes:&configurationVersion length:sizeof(uint8_t)];
            [avcCData appendBytes:&AVCProfileIndication length:sizeof(uint8_t)];
            [avcCData appendBytes:&profile_compat length:sizeof(uint8_t)];
            [avcCData appendBytes:&AVCLevelIndication length:sizeof(uint8_t)];
            [avcCData appendBytes:&sampleLenFieldSizeMinusOne length:sizeof(uint8_t)];

            uint8_t *buffer = nal.buffer + header_size;
            uint32_t buffersize = nal.buffer_on - header_size;
            uint32_t iy = 0;

            NSMutableData *seqData = [[NSMutableData alloc] init];
            uint16_t temp = buffersize << 8;
            [seqData appendBytes:&temp length:sizeof(uint16_t)];
            [seqData appendBytes:buffer length:buffersize];
            iy++;

            [avcCData appendBytes:&iy length:sizeof(uint8_t)];
            [avcCData appendData:seqData];

            [seqData release];

            // skip the nal type byte
            if (h264_read_seq_info(nal.buffer, nal.buffer_on, &h264_dec) == -1)
            {
                // fprintf(stderr, "%s: Could not decode Sequence header\n", ProgName);
                fclose(inFile);
                return nil;
            }
            *pic_width = h264_dec.pic_width;
            *pic_height = h264_dec.pic_height;
            *profile = h264_dec.profile;
            *level = h264_dec.level;
        }
        else if (nal_type == H264_NAL_TYPE_PIC_PARAM && !have_pic) {
            have_pic = true;
            
            uint8_t *buffer = nal.buffer + header_size;
            uint32_t buffersize = nal.buffer_on - header_size;

            uint32_t iy = 0;

            NSMutableData *pictData = [[NSMutableData alloc] init];
                uint16_t temp = buffersize << 8;
                [pictData appendBytes:&temp length:sizeof(uint16_t)];
                [pictData appendBytes:buffer length:buffersize];
                iy++;
            
            [avcCData appendBytes:&iy length:sizeof(uint8_t)];
            [avcCData appendData:pictData];
            
            [pictData release];

        }
    }

    fclose(inFile);
    return [avcCData copy];
}

@implementation MP42H264Importer

- (id)initWithDelegate:(id)del andFile:(NSString *)fileUrl
{
    if ((self = [super init])) {
        delegate = del;
        file = [fileUrl retain];

        tracksArray = [[NSMutableArray alloc] initWithCapacity:1];

        MP42VideoTrack *newTrack = [[MP42VideoTrack alloc] init];

        newTrack.format = @"H.264";
        newTrack.sourceFormat = @"H.264";
        newTrack.sourcePath = file;

        if (!inFile)
            inFile = fopen([file UTF8String], "rb");

        struct stat st;
        stat([file UTF8String], &st);
        size = st.st_size * 8;

        uint32_t tw, th;
        uint8_t profile, level;
        if ((avcC = H264Info([file cStringUsingEncoding:NSASCIIStringEncoding], &tw, &th, &profile, &level))) {
            newTrack.width = newTrack.trackWidth = tw;
            newTrack.height = newTrack.trackHeight = th;
            newTrack.hSpacing = newTrack.vSpacing = 1;
            newTrack.origProfile = newTrack.newProfile = profile;
            newTrack.origLevel = newTrack.newLevel = level;
        }

        [tracksArray addObject:newTrack];
        [newTrack release];
    }

    return self;
}

- (NSUInteger)timescaleForTrack:(MP42Track *)track
{
    framerate_t * framerate;

    for (framerate = (framerate_t*) framerates; framerate->code; framerate++)
        if([track sourceId] == framerate->code)
            break;

    timescale = framerate->timescale;
    mp4FrameDuration = framerate->duration;

    return timescale;
}

- (NSSize)sizeForTrack:(MP42Track *)track
{
      return NSMakeSize([(MP42VideoTrack*)track trackWidth], [(MP42VideoTrack*) track trackHeight]);
}

- (NSData*)magicCookieForTrack:(MP42Track *)track
{
    
    return avcC;
}

- (void) fillMovieSampleBuffer: (id)sender
{
    NSAutoreleasePool * pool = [[NSAutoreleasePool alloc] init];
    if (!inFile)
        inFile = fopen([file UTF8String], "rb");

    MP42Track *track = [activeTracks lastObject];
    MP4TrackId dstTrackId = [track Id];

    framerate_t * framerate;

    for (framerate = (framerate_t*) framerates; framerate->code; framerate++)
        if([track sourceId] == framerate->code)
            break;

    timescale = framerate->timescale;
    mp4FrameDuration = framerate->duration;


    // the current syntactical object
    // typically 1:1 with a sample
    // but not always, i.e. non-VOP's
    // the current sample
    MP4SampleId sampleId = 1;

    // track configuration info
    nal_reader_t nal;
    h264_decode_t h264_dec;

    memset(&nal, 0, sizeof(nal));
    nal.ifile = inFile;

    if (timescale == 0) {
        fprintf(stderr, "%s: Must specify a timescale when reading H.264 files", 
                ProgName);
        timescale = 30000;
        mp4FrameDuration = 1001;
    }

    rewind(nal.ifile);
    nal.buffer_size = 0;
    nal.buffer_on = 0;
    nal.buffer_size_max = 0;
    free(nal.buffer);
    nal.buffer = NULL;

    uint8_t *nal_buffer;
    uint32_t nal_buffer_size, nal_buffer_size_max;
    nal_buffer = NULL;
    nal_buffer_size = 0;
    nal_buffer_size_max = 0;
    bool first = true;
    bool nal_is_sync = false;
    bool slice_is_idr = false;
    int32_t poc = 0;
    uint32_t dflags = 0;
    
    // now process the rest of the video stream
    memset(&h264_dec, 0, sizeof(h264_dec));
    DpbInit(&h264_dpb);
    
    while ( (LoadNal(&nal) != false) && !isCancelled) {
        uint32_t header_size;
        header_size = nal.buffer[2] == 1 ? 3 : 4;
        bool boundary = h264_detect_boundary(nal.buffer, 
                                             nal.buffer_on,
                                             &h264_dec);

        if (boundary && first == false) {
            // write the previous sample
            if (nal_buffer_size != 0) {
                samplesWritten++;
                
                void* sampleData = malloc(nal_buffer_size);
                memcpy(sampleData, nal_buffer, nal_buffer_size);
                
                MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
                sample->sampleData = sampleData;
                sample->sampleSize = nal_buffer_size;
                sample->sampleDuration = mp4FrameDuration;
                sample->sampleOffset = 0;
                sample->sampleTimestamp = 0;
                sample->sampleIsSync = nal_is_sync;
                sample->sampleTrackId = dstTrackId;
                if(track.needConversion)
                    sample->sampleSourceTrack = track;
                
                @synchronized(samplesBuffer) {
                    [samplesBuffer addObject:sample];
                    [sample release];
                }

                sampleId++;
                DpbAdd( &h264_dpb, poc, slice_is_idr );
                nal_is_sync = false;
                nal_buffer_size = 0;
            } 
        }
        bool copy_nal_to_buffer = false;
        if (Verbosity) {
            printf("H264 type %x size %u\n",
                   h264_dec.nal_unit_type, nal.buffer_on);
        }
        if (h264_nal_unit_type_is_slice(h264_dec.nal_unit_type)) {
            dflags = h264_get_frame_dependency(&h264_dec);
            // copy all seis, etc before indicating first
            first = false;
            copy_nal_to_buffer = true;
            slice_is_idr = h264_dec.nal_unit_type == H264_NAL_TYPE_IDR_SLICE;
            poc = h264_dec.pic_order_cnt;
            
            nal_is_sync = h264_slice_is_idr(&h264_dec);
        } else {
            switch (h264_dec.nal_unit_type) {
                case H264_NAL_TYPE_SEQ_PARAM:
                    // doesn't get added to sample buffer
                    // remove header
                    //MP4AddH264SequenceParameterSet(mp4File, trackId, 
                    //                               nal.buffer + header_size, 
                    //                               nal.buffer_on - header_size);
                    break;
                case H264_NAL_TYPE_PIC_PARAM:
                    // doesn't get added to sample buffer
                    //MP4AddH264PictureParameterSet(mp4File, trackId, 
                    //                              nal.buffer + header_size, 
                    //                              nal.buffer_on - header_size);
                    break;
                case H264_NAL_TYPE_FILLER_DATA:
                    // doesn't get copied
                    break;
                case H264_NAL_TYPE_SEI:
                    copy_nal_to_buffer = remove_unused_sei_messages(&nal, header_size);
                    break;
                case H264_NAL_TYPE_ACCESS_UNIT: 
                    // note - may not want to copy this - not needed
                default:
                    copy_nal_to_buffer = true;
                    break;
            }
        }
        if (copy_nal_to_buffer) {
            uint32_t to_write;
            to_write = nal.buffer_on - header_size;
            if (to_write + 4 + nal_buffer_size > nal_buffer_size_max) {
                nal_buffer_size_max += nal.buffer_on + 4;
                nal_buffer = (uint8_t *)realloc(nal_buffer, nal_buffer_size_max);
            }
            nal_buffer[nal_buffer_size] = (to_write >> 24) & 0xff;
            nal_buffer[nal_buffer_size + 1] = (to_write >> 16) & 0xff;
            nal_buffer[nal_buffer_size + 2] = (to_write >> 8) & 0xff;
            nal_buffer[nal_buffer_size + 3] = to_write & 0xff;
            memcpy(nal_buffer + nal_buffer_size + 4,
                   nal.buffer + header_size,
                   to_write);

            nal_buffer_size += to_write + 4;
        }
    }

    if (nal_buffer_size != 0) {
        samplesWritten++;
    
        void* sampleData = malloc(nal_buffer_size);
        memcpy(sampleData, nal_buffer, nal_buffer_size);
        
        MP42SampleBuffer *sample = [[MP42SampleBuffer alloc] init];
        sample->sampleData = sampleData;
        sample->sampleSize = nal_buffer_size;
        sample->sampleDuration = mp4FrameDuration;
        sample->sampleOffset = 0;
        sample->sampleTimestamp = 0;
        sample->sampleIsSync = nal_is_sync;
        sample->sampleTrackId = dstTrackId;
        if(track.needConversion)
            sample->sampleSourceTrack = track;

        @synchronized(samplesBuffer) {
            [samplesBuffer addObject:sample];
            [sample release];
        }

        DpbAdd(&h264_dpb, h264_dec.pic_order_cnt, slice_is_idr);
    }

    DpbFlush(&h264_dpb);

    [pool release];
    readerStatus = 1;
}

- (BOOL)cleanUp:(MP4FileHandle) fileHandle
{
    MP42Track *track = [activeTracks lastObject];
    MP4TrackId trackId = [track Id];

    if (h264_dpb.dpb.size_min > 0) {
        unsigned int ix;

        for (ix = 0; ix < samplesWritten; ix++) {
            const int offset = DpbFrameOffset(&h264_dpb, ix);
            MP4SetSampleRenderingOffset(fileHandle, trackId, 1 + ix, 
                                        offset * mp4FrameDuration);
        }
        MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                               trackId,
                                                               MP4GetTrackDuration(fileHandle, trackId),
                                                               MP4GetTimeScale(fileHandle));

        MP4AddTrackEdit(fileHandle, trackId, MP4_INVALID_EDIT_ID, DpbFrameOffset(&h264_dpb, 0) * mp4FrameDuration,
                        editDuration, 0);
    }

    DpbClean(&h264_dpb);

    return YES;
}

- (MP42SampleBuffer*)copyNextSample {    
    if (samplesBuffer == nil) {
        samplesBuffer = [[NSMutableArray alloc] initWithCapacity:200];
    }

    if (!dataReader && !readerStatus) {
        dataReader = [[NSThread alloc] initWithTarget:self selector:@selector(fillMovieSampleBuffer:) object:self];
        [dataReader setName:@"H.264 Demuxer"];
        [dataReader start];
    }

    while (![samplesBuffer count] && !readerStatus)
        usleep(2000);

    if (readerStatus)
        if ([samplesBuffer count] == 0) {
            readerStatus = 0;
            [dataReader release];
            dataReader = nil;
            return nil;
        }

    MP42SampleBuffer* sample;

    @synchronized(samplesBuffer) {
        sample = [samplesBuffer objectAtIndex:0];
        [sample retain];
        [samplesBuffer removeObjectAtIndex:0];
    }

    return sample;
}

- (void)setActiveTrack:(MP42Track *)track {
    if (!activeTracks)
        activeTracks = [[NSMutableArray alloc] init];
    
    [activeTracks addObject:track];
}

- (CGFloat)progress
{
    return progress;
}

- (void) dealloc
{
    if (dataReader)
        [dataReader release];
    if (samplesBuffer)
        [samplesBuffer release];

    fclose(inFile);

    [avcC release];
	[file release];
    [tracksArray release];
    [activeTracks release];

    [super dealloc];
}

@end
