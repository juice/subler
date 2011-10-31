/*
 *  MP42Utilities.c
 *  Subler
 *
 *  Created by Damiano Galassi on 30/01/09.
 *  Copyright 2009 Damiano Galassi. All rights reserved.
 *
 */

#import "MP42Utilities.h"
#import <string.h>
#import <CoreAudio/CoreAudio.h>
#include <zlib.h>

#include "lang.h"
#include "intreadwrite.h"
#include "avcodec.h"

NSString* SRTStringFromTime( long long time, long timeScale , const char separator)
{
    NSString *SRT_string;
    int hour, minute, second, msecond;
    long long result;

    result = time / timeScale; // second

    msecond = (time % timeScale) / (timeScale / 1000.0f);
	
    second = result % 60;

    result = result / 60; // minute
    minute = result % 60;

    result = result / 60; // hour
    hour = result % 24;

    SRT_string = [NSString stringWithFormat:@"%02d:%02d:%02d%c%03d", hour, minute, second, separator, msecond]; // h:mm:ss:fff

    return SRT_string;
}

NSString* SMPTEStringFromTime( long long time, long timeScale )
{
    NSString *SMPTE_string;
    int hour, minute, second, frame;
    long long result;

    result = time / timeScale; // second
    frame = (time % timeScale) / 10;

    second = result % 60;

    result = result / 60; // minute
    minute = result % 60;

    result = result / 60; // hour
    hour = result % 24;

    SMPTE_string = [NSString stringWithFormat:@"%d:%02d:%02d:%02d", hour, minute, second, frame]; // h:mm:ss:ff

    return SMPTE_string;
}

MP4Duration TimeFromSMPTEString( NSString* SMPTE_string, MP4Duration timeScale )
{
    int hour, minute, second, frame;
    MP4Duration timeval;

    sscanf([SMPTE_string UTF8String], "%d:%02d:%02d:%02d",&hour, &minute, &second, &frame);

    timeval = hour * 60 * 60 + minute * 60 + second;
	timeval = timeScale * timeval + ( frame * 10 );

    return timeval;
}


int enableTrack(MP4FileHandle fileHandle, MP4TrackId trackId)
{
    return MP4SetTrackIntegerProperty(fileHandle, trackId, "tkhd.flags", (TRACK_ENABLED | TRACK_IN_MOVIE));
}

int disableTrack(MP4FileHandle fileHandle, MP4TrackId trackId)
{
    return MP4SetTrackIntegerProperty(fileHandle, trackId, "tkhd.flags", (TRACK_DISABLED | TRACK_IN_MOVIE));
}

int enableFirstSubtitleTrack(MP4FileHandle fileHandle)
{
    unsigned int i, firstTrack = 0;
    for (i = 0; i < MP4GetNumberOfTracks( fileHandle, 0, 0); i++) {
        const char* trackType = MP4GetTrackType( fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
        
        if (!strcmp(trackType, MP4_SUBTITLE_TRACK_TYPE))
            if (firstTrack++ == 0)
                enableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
            else
                disableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
    }
        return 0;
}

int enableFirstAudioTrack(MP4FileHandle fileHandle)
{
    unsigned int i, firstTrack = 0;
    for (i = 0; i < MP4GetNumberOfTracks( fileHandle, 0, 0); i++) {
        const char* trackType = MP4GetTrackType( fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
        
        if (!strcmp(trackType, MP4_AUDIO_TRACK_TYPE)) {
            MP4SetTrackIntegerProperty(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0), "tkhd.alternate_group", 1);
            if (firstTrack++ == 0)
                enableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
            else
                disableTrack(fileHandle, MP4FindTrackId( fileHandle, i, 0, 0));
        }
    }
    return 0;
}

int updateTracksCount(MP4FileHandle fileHandle)
{
    MP4TrackId maxTrackId = 0;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ )
        if (MP4FindTrackId(fileHandle, i, 0, 0) > maxTrackId)
            maxTrackId = MP4FindTrackId(fileHandle, i, 0, 0);

    return MP4SetIntegerProperty(fileHandle, "moov.mvhd.nextTrackId", maxTrackId + 1);
}

void updateMoovDuration(MP4FileHandle fileHandle) {
    MP4TrackId trackId = 0;
    MP4Duration maxTrackDuration = 0, trackDuration = 0;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ ) {
        trackId = MP4FindTrackId(fileHandle, i, 0, 0);
        MP4GetTrackIntegerProperty(fileHandle, trackId, "tkhd.duration", &trackDuration);
        if (maxTrackDuration < trackDuration)
            maxTrackDuration = trackDuration;
    }
    MP4SetIntegerProperty(fileHandle, "moov.mvhd.duration", maxTrackDuration);
}

MP4TrackId findChapterTrackId(MP4FileHandle fileHandle)
{
    MP4TrackId trackId = 0;
    uint64_t trackRef;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ ) {
        trackId = MP4FindTrackId(fileHandle, i, 0, 0);
        if (MP4HaveTrackAtom(fileHandle, trackId, "tref.chap")) {
            MP4GetTrackIntegerProperty(fileHandle, trackId, "tref.chap.entries.trackId", &trackRef);
            if (trackRef > 0)
                return (MP4TrackId) trackRef;
        }
    }
    return 0;
}

void removeAllChapterTrackReferences(MP4FileHandle fileHandle)
{
    MP4TrackId trackId = 0;
    unsigned int i;
    for (i = 0; i< MP4GetNumberOfTracks( fileHandle, 0, 0); i++ ) {
        trackId = MP4FindTrackId(fileHandle, i, 0, 0);
        if (MP4HaveTrackAtom(fileHandle, trackId, "tref.chap")) {
            MP4RemoveAllTrackReferences(fileHandle, "tref.chap", trackId);
        }
    }
    return;
}

MP4TrackId findFirstVideoTrack(MP4FileHandle fileHandle)
{
    MP4TrackId videoTrack = 0;
    int i, trackNumber = MP4GetNumberOfTracks( fileHandle, 0, 0);
    if (!trackNumber)
        return 0;
    for (i = 0; i <= trackNumber; i++) {
        videoTrack = MP4FindTrackId( fileHandle, i, 0, 0);
        const char* trackType = MP4GetTrackType(fileHandle, videoTrack);
        if (trackType)
            if (!strcmp(trackType, MP4_VIDEO_TRACK_TYPE))
                return videoTrack;
    }
    return 0;
}

uint16_t getFixedVideoWidth(MP4FileHandle fileHandle, MP4TrackId Id)
{
    uint16_t videoWidth = MP4GetTrackVideoWidth(fileHandle, Id);

    if (MP4HaveTrackAtom(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp")) {
        uint64_t hSpacing, vSpacing;
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.hSpacing", &hSpacing);
        MP4GetTrackIntegerProperty(fileHandle, Id, "mdia.minf.stbl.stsd.*.pasp.vSpacing", &vSpacing);
        if( hSpacing > 0 && vSpacing > 0)
            return  (uint16_t) (videoWidth / (float) vSpacing * (float) hSpacing);
        else
            return videoWidth;
    }

    return videoWidth;
}

NSString* getTrackName(MP4FileHandle fileHandle, MP4TrackId Id)
{
    char *trackName;

    if (MP4GetTrackName(fileHandle, Id, &trackName)) {
        NSString * name = [NSString stringWithUTF8String: trackName];
        free(trackName);
        return name;
    }

    const char* type = MP4GetTrackType(fileHandle, Id);
    if (!strcmp(type, MP4_AUDIO_TRACK_TYPE))
        return NSLocalizedString(@"Sound Track", @"Sound Track");
    else if (!strcmp(type, MP4_VIDEO_TRACK_TYPE))
        return NSLocalizedString(@"Video Track", @"Video Track");
    else if (!strcmp(type, MP4_TEXT_TRACK_TYPE))
        return NSLocalizedString(@"Text Track", @"Text Track");
    else if (!strcmp(type, MP4_SUBTITLE_TRACK_TYPE))
        return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
    else if (!strcmp(type, "clcp"))
        return NSLocalizedString(@"Closed Caption Track", @"Closed Caption Track");
    else if (!strcmp(type, MP4_OD_TRACK_TYPE))
        return NSLocalizedString(@"MPEG-4 ODSM Track", @"MPEG-4 ODSM Track");
    else if (!strcmp(type, MP4_SCENE_TRACK_TYPE))
        return NSLocalizedString(@"MPEG-4 SDSM Track", @"MPEG-4 SDSM Track");
    else if (!strcmp(type, "tmcd"))
        return NSLocalizedString(@"Timecode Track", @"Timecode Track");
    else if (!strcmp(type, "subp"))
        return NSLocalizedString(@"Subtitle Track", @"Subtitle Track");
    else
        return NSLocalizedString(@"Unknown Track", @"Unknown Track");
}

NSString* getHumanReadableTrackMediaDataName(MP4FileHandle fileHandle, MP4TrackId Id)
{
    const char* type = MP4GetTrackType(fileHandle, Id);
    const char* dataName = MP4GetTrackMediaDataName(fileHandle, Id);
    if (dataName) {
        if (!strcmp(dataName, "avc1"))
            return @"H.264";
        else if (!strcmp(dataName, "mp4a"))
            return @"AAC";
        else if (!strcmp(dataName, "alac"))
            return @"ALAC";
        else if (!strcmp(dataName, "ac-3"))
            return @"AC-3";
        else if (!strcmp(dataName, "mp4v"))
            return @"MPEG-4 Visual";
        else if (!strcmp(dataName, "text"))
            return @"Text";
        else if (!strcmp(dataName, "tx3g"))
            return @"3GPP Text";
        else if (!strcmp(dataName, "c608"))
            return @"CEA-608";
        else if (!strcmp(dataName, "c708"))
            return @"CEA-708";
        else if (!strcmp(dataName, "samr"))
            return @"AMR Narrow Band";
        else if (!strcmp(dataName, "jpeg"))
            return @"Photo - JPEG";
        else if (!strcmp(dataName, "rtp "))
            return @"Hint";
        else if (!strcmp(dataName, "drms"))
            return @"FairPlay Sound";
        else if (!strcmp(dataName, "drmi"))
            return @"FairPlay Video";
        else if (!strcmp(dataName, "tmcd"))
            return @"Timecode";
        else if (!strcmp(dataName, "mp4s") && !strcmp(type, "subp"))
            return @"VobSub";

        else
            return [NSString stringWithUTF8String:dataName];
    }
    else {
        return @"Unknown";
    }

}

NSString* getHumanReadableTrackLanguage(MP4FileHandle fileHandle, MP4TrackId Id)
{
    NSString *language;
    char lang[4] = "";
    MP4GetTrackLanguage(fileHandle, Id, lang);
    language = [NSString stringWithFormat:@"%s", lang_for_code2(lang)->eng_name];

    return language;
}

// if the subtitle filename is something like title.en.srt or movie.fre.srt
// this function detects it and returns the subtitle language
NSString* getFilenameLanguage(CFStringRef filename)
{
	CFRange findResult;
	CFStringRef baseName = NULL;
	CFStringRef langStr = NULL;
	NSString *lang = @"English";

	// find and strip the extension
	findResult = CFStringFind(filename, CFSTR("."), kCFCompareBackwards);
	findResult.length = findResult.location;
	findResult.location = 0;
	baseName = CFStringCreateWithSubstring(NULL, filename, findResult);

	// then find the previous period
	findResult = CFStringFind(baseName, CFSTR("."), kCFCompareBackwards);
	findResult.location++;
	findResult.length = CFStringGetLength(baseName) - findResult.location;

	// check for 3 char language code
	if (findResult.length == 3) {
		char langCStr[4] = "";

		langStr = CFStringCreateWithSubstring(NULL, baseName, findResult);
		CFStringGetCString(langStr, langCStr, 4, kCFStringEncodingASCII);
        lang = [NSString stringWithFormat:@"%s", lang_for_code2(langCStr)->eng_name];

		CFRelease(langStr);

		// and for a 2 char language code
	} else if (findResult.length == 2) {
		char langCStr[3] = "";

		langStr = CFStringCreateWithSubstring(NULL, baseName, findResult);
		CFStringGetCString(langStr, langCStr, 3, kCFStringEncodingASCII);
        lang = [NSString stringWithFormat:@"%s", lang_for_code2(langCStr)->eng_name];

		CFRelease(langStr);
	}

	CFRelease(baseName);
	return lang;
}

/* write the data to the target adress & then return a pointer which points after the written data */
uint8_t *write_data(uint8_t *target, uint8_t* data, int32_t data_size)
{
	if(data_size > 0)
		memcpy(target, data, data_size);
	return (target + data_size);
} /* write_data() */

/* write the int32_t data to target & then return a pointer which points after that data */
uint8_t *write_int32(uint8_t *target, int32_t data)
{
	return write_data(target, (uint8_t*)&data, sizeof(data));
} /* write_int32() */

/* write the int16_t data to target & then return a pointer which points after that data */
uint8_t *write_int16(uint8_t *target, int16_t data)
{
	return write_data(target, (uint8_t*)&data, sizeof(data));
} /* write_int16() */

#define MP4ESDescrTag                   0x03
#define MP4DecConfigDescrTag            0x04
#define MP4DecSpecificDescrTag          0x05

// from perian
// based off of mov_mp4_read_descr_len from mov.c in ffmpeg's libavformat
static int readDescrLen(UInt8 **buffer)
{
	int len = 0;
	int count = 4;
	while (count--) {
		int c = *(*buffer)++;
		len = (len << 7) | (c & 0x7f);
		if (!(c & 0x80))
			break;
	}
	return len;
}

// based off of mov_mp4_read_descr from mov.c in ffmpeg's libavformat
static int readDescr(UInt8 **buffer, int *tag)
{
	*tag = *(*buffer)++;
	return readDescrLen(buffer);
}

// based off of mov_read_esds from mov.c in ffmpeg's libavformat
ComponentResult ReadESDSDescExt(void* descExt, UInt8 **buffer, int *size, int versionFlags)
{
	UInt8 *esds = (UInt8 *) descExt;
	int tag, len;
	*size = 0;

    if (versionFlags)
        esds += 4;		// version + flags
	readDescr(&esds, &tag);
	esds += 2;		// ID
	if (tag == MP4ESDescrTag)
		esds++;		// priority

	readDescr(&esds, &tag);
	if (tag == MP4DecConfigDescrTag) {
		esds++;		// object type id
		esds++;		// stream type
		esds += 3;	// buffer size db
		esds += 4;	// max bitrate
		esds += 4;	// average bitrate

		len = readDescr(&esds, &tag);
		if (tag == MP4DecSpecificDescrTag) {
			*buffer = calloc(1, len + 8);
			if (*buffer) {
				memcpy(*buffer, esds, len);
				*size = len;
			}
		}
	}

	return noErr;
}

// the esds atom creation is based off of the routines for it in ffmpeg's movenc.c
static unsigned int descrLength(unsigned int len)
{
    int i;
    for(i=1; len>>(7*i); i++);
    return len + 1 + i;
}

static uint8_t* putDescr(uint8_t *buffer, int tag, unsigned int size)
{
    int i= descrLength(size) - size - 2;
    *buffer++ = tag;
    for(; i>0; i--)
        *buffer++ = (size>>(7*i)) | 0x80;
    *buffer++ = size & 0x7F;
	return buffer;
}

// ESDS layout:
//  + version             (4 bytes)
//  + ES descriptor 
//   + Track ID            (2 bytes)
//   + Flags               (1 byte)
//   + DecoderConfig descriptor
//    + Object Type         (1 byte)
//    + Stream Type         (1 byte)
//    + Buffersize DB       (3 bytes)
//    + Max bitrate         (4 bytes)
//    + VBR/Avg bitrate     (4 bytes)
//    + DecoderSpecific info descriptor
//     + codecPrivate        (codecPrivate->GetSize())
//   + SL descriptor
//    + dunno               (1 byte)

uint8_t *CreateEsdsFromSetupData(uint8_t *codecPrivate, size_t vosLen, size_t *esdsLen, int trackID, bool audio, bool write_version)
{
	int decoderSpecificInfoLen = vosLen ? descrLength(vosLen) : 0;
	int versionLen = write_version ? 4 : 0;
	
	*esdsLen = versionLen + descrLength(3 + descrLength(13 + decoderSpecificInfoLen) + descrLength(1));
	uint8_t *esds = (uint8_t*)malloc(*esdsLen);
	UInt8 *pos = (UInt8 *) esds;
	
	// esds atom version (only needed for ImageDescription extension)
	if (write_version)
		pos = write_int32(pos, 0);
	
	// ES Descriptor
	pos = putDescr(pos, 0x03, 3 + descrLength(13 + decoderSpecificInfoLen) + descrLength(1));
	pos = write_int16(pos, EndianS16_NtoB(trackID));
	*pos++ = 0;		// no flags
	
	// DecoderConfig descriptor
	pos = putDescr(pos, 0x04, 13 + decoderSpecificInfoLen);
	
	// Object type indication, see http://gpac.sourceforge.net/tutorial/mediatypes.htm
	if (audio)
		*pos++ = 0x40;		// aac
	else
		*pos++ = 0x20;		// mpeg4 part 2
	
	// streamtype
	if (audio)
		*pos++ = 0x15;
	else
		*pos++ = 0x11;
	
	// 3 bytes: buffersize DB (not sure how to get easily)
	*pos++ = 0;
	pos = write_int16(pos, 0);
	
	// max bitrate, not sure how to get easily
	pos = write_int32(pos, 0);
	
	// vbr
	pos = write_int32(pos, 0);
	
	if (vosLen) {
		pos = putDescr(pos, 0x05, vosLen);
		pos = write_data(pos, codecPrivate, vosLen);
	}
	
	// SL descriptor
	pos = putDescr(pos, 0x06, 1);
	*pos++ = 0x02;
	
	return esds;
}

enum {
	// these are atoms/extension types defined by XiphQT for their codecs
	kCookieTypeOggSerialNo = 'oCtN',
    
	kCookieTypeVorbisHeader = 'vCtH',
	kCookieTypeVorbisComments = 'vCt#',
	kCookieTypeVorbisCodebooks = 'vCtC',
	kCookieTypeVorbisFirstPageNo = 'vCtN',
    
	kCookieTypeSpeexHeader = 'sCtH',
	kCookieTypeSpeexComments = 'sCt#',
	kCookieTypeSpeexExtraHeader	= 'sCtX',
    
	kCookieTypeFLACStreaminfo = 'fCtS',
	kCookieTypeFLACMetadata = 'fCtM',
};

// xiph-qt expects these this sound extension to have been created from first 3 packets
// which are stored in CodecPrivate in Matroska
CFDataRef createDescExt_XiphVorbis(UInt32 codecPrivateSize, const void * codecPrivate)
{
	if (codecPrivateSize) {
        CFMutableDataRef sndDescExt = CFDataCreateMutable(NULL, 0);
        
		unsigned char *privateBuf;
		size_t privateSize;
		uint8_t numPackets;
		int offset = 1, i;
		UInt32 uid = 0;
        
		privateSize = codecPrivateSize;
		privateBuf = (unsigned char *) codecPrivate;
		numPackets = privateBuf[0] + 1;
        
		int packetSizes[numPackets];
		memset(packetSizes, 0, sizeof(packetSizes));
        
		// get the sizes of the packets
		packetSizes[numPackets - 1] = privateSize - 1;
		int packetNum = 0;
		for (i = 1; packetNum < numPackets - 1; i++) {
			packetSizes[packetNum] += privateBuf[i];
			if (privateBuf[i] < 255) {
				packetSizes[numPackets - 1] -= packetSizes[packetNum];
				packetNum++;
			}
			offset++;
		}
		packetSizes[numPackets - 1] -= offset - 1;
        
		if (offset+packetSizes[0]+packetSizes[1]+packetSizes[2] > privateSize) {
            CFRelease(sndDescExt);
			return NULL;
		}
        
		// first packet
		uint32_t serial_header_atoms[3+2] = { EndianU32_NtoB(3*4), 
			EndianU32_NtoB(kCookieTypeOggSerialNo), 
			EndianU32_NtoB(uid),
			EndianU32_NtoB(packetSizes[0] + 2*4), 
			EndianU32_NtoB(kCookieTypeVorbisHeader) };
        
        CFDataAppendBytes(sndDescExt, (UInt8 *)serial_header_atoms, sizeof(serial_header_atoms));
        CFDataAppendBytes(sndDescExt, &privateBuf[offset], packetSizes[0]);
        
		// second packet
		uint32_t atomhead2[2] = { EndianU32_NtoB(packetSizes[1] + sizeof(atomhead2)), 
			EndianU32_NtoB(kCookieTypeVorbisComments) };
        CFDataAppendBytes(sndDescExt, (UInt8 *)atomhead2, sizeof(atomhead2));
        CFDataAppendBytes(sndDescExt, &privateBuf[offset + packetSizes[0]], packetSizes[1]);
        
		// third packet
		uint32_t atomhead3[2] = { EndianU32_NtoB(packetSizes[2] + sizeof(atomhead3)), 
			EndianU32_NtoB(kCookieTypeVorbisCodebooks) };
        CFDataAppendBytes(sndDescExt, (UInt8 *)atomhead3, sizeof(atomhead3));
        CFDataAppendBytes(sndDescExt, &privateBuf[offset + packetSizes[1] + packetSizes[0]], packetSizes[2]);
        
        return sndDescExt;
	}
	return NULL;
}

// xiph-qt expects these this sound extension to have been created in this way
// from the packets which are stored in the CodecPrivate element in Matroska
CFDataRef createDescExt_XiphFLAC(UInt32 codecPrivateSize, const void * codecPrivate)
{	
	if (codecPrivateSize) {
        CFMutableDataRef sndDescExt = CFDataCreateMutable(NULL, 0);
		UInt32 uid = 0;

		size_t privateSize = codecPrivateSize;
		UInt8 *privateBuf = (unsigned char *) codecPrivate, *privateEnd = privateBuf + privateSize;

		unsigned long serialnoatom[3] = { EndianU32_NtoB(sizeof(serialnoatom)), 
			EndianU32_NtoB(kCookieTypeOggSerialNo), 
			EndianU32_NtoB(uid) };

        CFDataAppendBytes(sndDescExt, (UInt8 *)serialnoatom, sizeof(serialnoatom));

		privateBuf += 4; // skip 'fLaC'

		while ((privateEnd - privateBuf) > 4) {
			uint32_t packetHeader = EndianU32_BtoN(*(uint32_t*)privateBuf);
			int lastPacket = packetHeader >> 31, blockType = (packetHeader >> 24) & 0x7F;
			uint32_t packetSize = (packetHeader & 0xFFFFFF) + 4;
			uint32_t xiphHeader[2] = {EndianU32_NtoB(packetSize + sizeof(xiphHeader)),
				EndianU32_NtoB(blockType ? kCookieTypeFLACMetadata : kCookieTypeFLACStreaminfo)};

			if ((privateEnd - privateBuf) < packetSize)
				break;

            CFDataAppendBytes(sndDescExt, (UInt8 *)xiphHeader, sizeof(xiphHeader));
            CFDataAppendBytes(sndDescExt, privateBuf, packetSize);
            
			privateBuf += packetSize;
            
			if (lastPacket)
				break;
		}

		return sndDescExt;	
	}
	return nil;
}

static const int ac3_layout_no_lfe[8] = {
	kAudioChannelLayoutTag_Stereo,
	kAudioChannelLayoutTag_Mono,
	kAudioChannelLayoutTag_Stereo,
	kAudioChannelLayoutTag_ITU_3_0,
	kAudioChannelLayoutTag_ITU_2_1,
	kAudioChannelLayoutTag_ITU_3_1,
	kAudioChannelLayoutTag_ITU_2_2,
	kAudioChannelLayoutTag_ITU_3_2};

static const int ac3_layout_lfe[8] = {
	kAudioChannelLayoutTag_DVD_4,
	kAudioChannelLayoutTag_AC3_1_0_1,
	kAudioChannelLayoutTag_DVD_4,
	kAudioChannelLayoutTag_DVD_10,
	kAudioChannelLayoutTag_DVD_5,
	kAudioChannelLayoutTag_DVD_11,
	kAudioChannelLayoutTag_DVD_6,
	kAudioChannelLayoutTag_ITU_3_2_1};

int readAC3Config(uint64_t acmod, uint64_t lfeon, UInt32 *channelsCount, UInt32 *channelLayoutTag)
{
	if(lfeon)
		*channelLayoutTag = ac3_layout_lfe[acmod];
	else
		*channelLayoutTag = ac3_layout_no_lfe[acmod];

    *channelsCount = AudioChannelLayoutTag_GetNumberOfChannels(*channelLayoutTag);

    return 1;
}

BOOL isTrackMuxable(NSString * formatName)
{
    NSArray* supportedFormats = [NSArray arrayWithObjects:@"H.264", @"MPEG-4 Visual", @"AAC", @"AC-3", @"3GPP Text", @"Text",
                                 @"CEA-608", /*@"Photo - JPEG",*/ @"VobSub", nil];

    for (NSString* type in supportedFormats)
        if ([formatName isEqualToString:type])
            return YES;

    return NO;
}

BOOL trackNeedConversion(NSString * formatName) {
    NSArray* supportedConversionFormats = [NSArray arrayWithObjects:@"Vorbis", @"DTS", @"Flac", @"Mp3", @"True HD", @"ASS", @"SSA", @"Plain Text", nil];

    for (NSString* type in supportedConversionFormats)
        if ([formatName isEqualToString:type])
            return YES;

    return NO;
}

int64_t getTrackStartOffset(MP4FileHandle fileHandle, MP4TrackId Id)
{
    int64_t offset = 0;
    uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(fileHandle, Id);

    while (i <= trackEditCount) {
        MP4Duration editDuration = MP4GetTrackEditDuration(fileHandle, Id, i);
        MP4Timestamp editMediaTime = MP4GetTrackEditMediaStart(fileHandle, Id, i);
        //int8_t editMediaRate = MP4GetTrackEditDwell(fileHandle, Id, i);

        uint64_t editListVersion = 0;
        MP4GetTrackIntegerProperty(fileHandle, Id, "edts.elst.version", &editListVersion);

        if (editListVersion == 0 && editMediaTime == ((uint32_t)-1))
                offset += MP4ConvertFromMovieDuration(fileHandle, editDuration, MP4_MILLISECONDS_TIME_SCALE);
        else if (editListVersion == 1 && editMediaTime == ((uint64_t)-1))
                offset += MP4ConvertFromMovieDuration(fileHandle, editDuration, MP4_MILLISECONDS_TIME_SCALE);
        else if (i == 1)
            offset -= MP4ConvertFromTrackDuration(fileHandle, Id, editMediaTime, MP4_MILLISECONDS_TIME_SCALE);

        //NSLog(@"Track %d, Media Time = %lld, Segment Duration: %qu Media Rate:%d", Id, editMediaTime, editDuration, editMediaRate);
        i++;
    }

    //NSLog(@"Track %d offset: %d ms", Id, offset);

    return offset;
}

MP4Duration getTrackDuration(MP4FileHandle fileHandle, MP4TrackId trackId)
{
    uint32_t trackEditsCount = MP4GetTrackNumberOfEdits(fileHandle, trackId);
    MP4Duration duration = 0;
    int i = 1;
    
    while( i <= trackEditsCount) {
        duration += MP4GetTrackEditDuration(fileHandle, trackId, i);
        i++;
    }
    
    if (duration == 0)
        duration = MP4ConvertFromTrackDuration(fileHandle, trackId,
                                               MP4GetTrackDuration(fileHandle, trackId),
                                               MP4GetTimeScale(fileHandle));
    
    return duration;
}

void setTrackStartOffset(MP4FileHandle fileHandle, MP4TrackId Id, int64_t offset)
{
    uint32_t trackEditsCount = MP4GetTrackNumberOfEdits(fileHandle, Id);
    if (offset > 0)
        offset = MP4ConvertToTrackDuration(fileHandle, Id, offset, MP4_MILLISECONDS_TIME_SCALE);
    else 
        offset = -(MP4ConvertToTrackDuration(fileHandle, Id, -offset, MP4_MILLISECONDS_TIME_SCALE));

    // If there is no existing edit list, just add some new ones at the start and do the usual stuff.
    if (offset && !trackEditsCount) {
        MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                   Id,
                                                   MP4GetTrackDuration(fileHandle, Id),
                                                   MP4GetTimeScale(fileHandle));
        if (offset > 0) {
            MP4Duration delayDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                    Id,
                                                                    offset,
                                                                    MP4GetTimeScale(fileHandle));

            MP4AddTrackEdit(fileHandle, Id, MP4_INVALID_EDIT_ID, -1, delayDuration, 0);
            MP4AddTrackEdit(fileHandle, Id, MP4_INVALID_EDIT_ID, 0, editDuration, 0);
        }
        else if (offset < 0) {
            MP4Duration delayDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                    Id,
                                                                    -offset,
                                                                    MP4GetTimeScale(fileHandle));

            MP4AddTrackEdit(fileHandle, Id, MP4_INVALID_EDIT_ID, -offset, editDuration - delayDuration, 0);
        }
    }
    // If the mp4 contains already some edits list, try to reuse them
    else if (trackEditsCount) {
        if (offset >= 0) {
            // Remove all the empty edit lists
            while (MP4GetTrackNumberOfEdits(fileHandle, Id)) {
                uint64_t editListVersion = 0;
                MP4Timestamp editMediaTime = MP4GetTrackEditMediaStart(fileHandle, Id, 1);

                MP4GetTrackIntegerProperty(fileHandle, Id, "edts.elst.version", &editListVersion);
                
                if (editListVersion == 0 && editMediaTime == ((uint32_t)-1))
                    MP4DeleteTrackEdit(fileHandle, Id, 1);
                else if (editListVersion == 1 && editMediaTime == ((uint64_t)-1))
                    MP4DeleteTrackEdit(fileHandle, Id, 1);
                else {
                    if (getTrackStartOffset(fileHandle, Id) < 0) {
                        MP4Duration oldEditDuration = MP4GetTrackEditDuration(fileHandle, Id, 1);
                        MP4Duration oldEditMediaStart = MP4GetTrackEditMediaStart(fileHandle, Id, 1);
                        oldEditMediaStart = MP4ConvertFromTrackDuration(fileHandle,
                                                                        Id,
                                                                        oldEditMediaStart,
                                                                        MP4GetTimeScale(fileHandle));
                        MP4SetTrackEditDuration(fileHandle, Id, 1, oldEditDuration + oldEditMediaStart);
                        MP4SetTrackEditMediaStart(fileHandle, Id, 1, 0);

                    }
                    break;
                }
            }

            MP4Duration delayDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                    Id,
                                                                    offset,
                                                                    MP4GetTimeScale(fileHandle));
            
            if (offset != 0)
                MP4AddTrackEdit(fileHandle, Id, 1, -1, delayDuration, 0);
        }
        else if (offset < 0) {
            // First remove all the empty edit lists
            while (MP4GetTrackNumberOfEdits(fileHandle, Id)) {
                uint64_t editListVersion = 0;
                MP4Timestamp editMediaTime = MP4GetTrackEditMediaStart(fileHandle, Id, 1);
                
                MP4GetTrackIntegerProperty(fileHandle, Id, "edts.elst.version", &editListVersion);
                
                if (editListVersion == 0 && editMediaTime == ((uint32_t)-1))
                    MP4DeleteTrackEdit(fileHandle, Id, 1);
                else if (editListVersion == 1 && editMediaTime == ((uint64_t)-1))
                    MP4DeleteTrackEdit(fileHandle, Id, 1);
                else
                    break;
            }
            // If there is already an edit list reuse it
            if (MP4GetTrackNumberOfEdits(fileHandle, Id)) {

                MP4Duration oldEditDuration = MP4GetTrackEditDuration(fileHandle, Id, 1);
                MP4Duration oldEditMediaStart = MP4GetTrackEditMediaStart(fileHandle, Id, 1);
                oldEditMediaStart = MP4ConvertFromTrackDuration(fileHandle,
                                                                Id,
                                                                oldEditMediaStart,
                                                                MP4GetTimeScale(fileHandle));
                MP4Duration newOffsetDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                        Id,
                                                                        -offset,
                                                                        MP4GetTimeScale(fileHandle));

                MP4SetTrackEditDuration(fileHandle, Id, 1, oldEditDuration + oldEditMediaStart - newOffsetDuration);
                MP4SetTrackEditMediaStart(fileHandle, Id, 1, -offset);
            }
            // Else create a new one.
            else {
                MP4Duration delayDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                                        Id,
                                                                        -offset,
                                                                        MP4GetTimeScale(fileHandle));

                MP4AddTrackEdit(fileHandle, Id, 1, -1, delayDuration, 0);
            }
        }
    }

    // Update the duration in tkhd, the value must be the sum of the durations of all track's edits.
    MP4Duration totalDuration = getTrackDuration(fileHandle, Id);
    MP4SetTrackIntegerProperty(fileHandle, Id, "tkhd.duration", totalDuration);
    
    // Update the duration in mvhd.
    updateMoovDuration(fileHandle);
}

int copyTrackEditLists (MP4FileHandle fileHandle, MP4TrackId srcTrackId, MP4TrackId dstTrackId) {
    MP4Duration trackDuration = 0;
    uint32_t i = 1, trackEditCount = MP4GetTrackNumberOfEdits(fileHandle, srcTrackId);
    while (i <= trackEditCount) {
        MP4Timestamp editMediaStart = MP4GetTrackEditMediaStart(fileHandle, srcTrackId, i);
        MP4Duration editDuration = MP4ConvertFromMovieDuration(fileHandle,
                                                               MP4GetTrackEditDuration(fileHandle, srcTrackId, i),
                                                               MP4GetTimeScale(fileHandle));
        trackDuration += editDuration;
        int8_t editDwell = MP4GetTrackEditDwell(fileHandle, srcTrackId, i);
        
        MP4AddTrackEdit(fileHandle, dstTrackId, i, editMediaStart, editDuration, editDwell);
        i++;
    }
    if (trackEditCount)
        MP4SetTrackIntegerProperty(fileHandle, dstTrackId, "tkhd.duration", trackDuration);
    else {
        uint32_t firstFrameOffset = MP4GetSampleRenderingOffset(fileHandle, dstTrackId, 1);
        MP4Duration editDuration = MP4ConvertFromTrackDuration(fileHandle,
                                                               srcTrackId,
                                                               MP4GetTrackDuration(fileHandle, srcTrackId),
                                                               MP4GetTimeScale(fileHandle));
        MP4AddTrackEdit(fileHandle, dstTrackId, MP4_INVALID_EDIT_ID, firstFrameOffset,
                        editDuration, 0);
    }
    
    return 1;
}

NSError* MP42Error(NSString *description, NSString* recoverySuggestion, NSInteger code) {
    NSMutableDictionary *errorDetail = [NSMutableDictionary dictionary];
    [errorDetail setValue:description
                   forKey:NSLocalizedDescriptionKey];
    [errorDetail setValue:recoverySuggestion
                   forKey:NSLocalizedRecoverySuggestionErrorKey];

    return [NSError errorWithDomain:@"MP42Error"
                                code:100
                            userInfo:errorDetail];
}

// Taken from HandBrake common.c
int yuv2rgb(int yuv)
{
    double y, Cr, Cb;
    int r, g, b;
    
    y  = (yuv >> 16) & 0xff;
    Cb = (yuv >>  8) & 0xff;
    Cr = (yuv      ) & 0xff;
    
    r = 1.164 * (y - 16)                      + 2.018 * (Cb - 128);
    g = 1.164 * (y - 16) - 0.813 * (Cr - 128) - 0.391 * (Cb - 128);
    b = 1.164 * (y - 16) + 1.596 * (Cr - 128);
    
    r = (r < 0) ? 0 : r;
    g = (g < 0) ? 0 : g;
    b = (b < 0) ? 0 : b;
    
    r = (r > 255) ? 255 : r;
    g = (g > 255) ? 255 : g;
    b = (b > 255) ? 255 : b;
    
    return (r << 16) | (g << 8) | b;
}

int rgb2yuv(int rgb)
{
    double r, g, b;
    int y, Cr, Cb;
    
    r = (rgb >> 16) & 0xff;
    g = (rgb >>  8) & 0xff;
    b = (rgb      ) & 0xff;
    
    y  =  16. + ( 0.257 * r) + (0.504 * g) + (0.098 * b);
    Cb = 128. + (-0.148 * r) - (0.291 * g) + (0.439 * b);
    Cr = 128. + ( 0.439 * r) - (0.368 * g) - (0.071 * b);
    
    y = (y < 0) ? 0 : y;
    Cb = (Cb < 0) ? 0 : Cb;
    Cr = (Cr < 0) ? 0 : Cr;
    
    y = (y > 255) ? 255 : y;
    Cb = (Cb > 255) ? 255 : Cb;
    Cr = (Cr > 255) ? 255 : Cr;
    
    return (y << 16) | (Cr << 8) | Cb;
}

void *fast_realloc_with_padding(void *ptr, unsigned int *size, unsigned int min_size)
{
	void *res = ptr;
	av_fast_malloc(&res, size, min_size + FF_INPUT_BUFFER_PADDING_SIZE);
	if (res) memset(res + min_size, 0, FF_INPUT_BUFFER_PADDING_SIZE);
	return res;
}

void DecompressZlib(uint8_t **codecData, unsigned int *bufferSize, uint8_t *sampleData, uint64_t sampleSize)
{
    unsigned int bufferSizeDec = 0;
	ComponentResult err = noErr;
	z_stream strm;
	strm.zalloc = Z_NULL;
	strm.zfree = Z_NULL;
	strm.opaque = Z_NULL;
	strm.avail_in = 0;
	strm.next_in = Z_NULL;
	err = inflateInit(&strm);
	if (err != Z_OK) return;
    
	strm.avail_in = sampleSize;
	strm.next_in = sampleData;
    
	// first, get the size of the decompressed data
	strm.avail_out = 2;
	strm.next_out = *codecData;
    
	err = inflate(&strm, Z_SYNC_FLUSH);
	if (err < Z_OK) goto bail;
	if (strm.avail_out != 0) goto bail;
    
	// reallocate our buffer to be big enough to store the decompressed packet
	bufferSizeDec = AV_RB16(*codecData);
	*codecData = fast_realloc_with_padding(*codecData, bufferSize, bufferSizeDec);
    
	// then decompress the rest of it
	strm.avail_out = *bufferSize - 2;
	strm.next_out = *codecData + 2;
    
	inflate(&strm, Z_SYNC_FLUSH);
bail:
	inflateEnd(&strm);
    
    *bufferSize = bufferSizeDec;
}

