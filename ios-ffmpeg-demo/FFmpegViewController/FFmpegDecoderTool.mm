//
//  LEGOFFmpegTool.m
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import "FFmpegDecoderTool.h"

@interface FFmpegDecoderTool () {
    AVFormatContext *m_formatContext;
    AVCodecContext *m_videoCodecContext;
    AVFrame *m_videoFrame;
    
    int m_videoStreamIndex;
    int m_audioStreamIndex;
    int m_video_width, m_video_height, m_video_fps;
    /*  Flag  */
    BOOL m_isStopParse;
    
    BOOL    m_isFindIDR;
    int64_t m_base_time;
}
@property (nonatomic, copy) NSString *path;
@end

@implementation FFmpegDecoderTool

+ (void)initialize {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        av_register_all();
    });
}

- (instancetype)initWithPath:(NSString *)path
{
    if (self = [super init]) {
        _path = path;
        [self prepareParse];
        [self initDecoder];
    }
    return self;
}

- (void)prepareParse
{
    // context
    m_formatContext = [self createFormatContextByFilePath:self.path];
    
    // stream index
    m_videoStreamIndex = [self getAVStreamIndexWithFormatContext:m_formatContext isVideoStream:YES];
    
    // video stream
    AVStream *videoStream = m_formatContext->streams[m_videoStreamIndex];
    
    m_video_width  = videoStream->codecpar->width;
    m_video_height = videoStream->codecpar->height;
    m_video_fps    = AVStreamFPSTimeBase(videoStream);
    
    
//    BOOL isSupport = [self isSupportVideoStream:videoStream
//                                  formatContext:m_formatContext
//                                    sourceWidth:m_video_width
//                                   sourceHeight:m_video_height
//                                      sourceFps:m_video_fps];
//    if (!isSupport) {
//        log4cplus_error(kModuleName, "%s: Not support the video stream",__func__);
//        return;
//    }
    
    // audio stream index
    m_audioStreamIndex = [self getAVStreamIndexWithFormatContext:m_formatContext isVideoStream:NO];
    
    // audio stream
    AVStream *audioStream = m_formatContext->streams[m_audioStreamIndex];
    
//    isSupport = [self isSupportAudioStream:audioStream
//                             formatContext:m_formatContext];
//    if (!isSupport) {
//        log4cplus_error(kModuleName, "%s: Not support the audio stream",__func__);
//        return;
//    }
}

- (AVFormatContext *)createFormatContextByFilePath:(NSString *)filePath {
    AVFormatContext  *formatContext = NULL;
    AVDictionary     *opts          = NULL;
    // 设置超时1秒
    av_dict_set(&opts, "timeout", "1000000", 0);
    formatContext = avformat_alloc_context();
    BOOL isSuccess = avformat_open_input(&formatContext, [filePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, &opts) < 0 ? NO : YES;
    NSLog(@"create format context isSuccess=%d",isSuccess);
    av_dict_free(&opts);
    return formatContext;
}

- (int)getAVStreamIndexWithFormatContext:(AVFormatContext *)formatContext isVideoStream:(BOOL)isVideoStream {
    int avStreamIndex = -1;
    for (int i = 0; i < formatContext->nb_streams; i++) {
        if ((isVideoStream ? AVMEDIA_TYPE_VIDEO : AVMEDIA_TYPE_AUDIO) == formatContext->streams[i]->codecpar->codec_type) {
            avStreamIndex = i;
        }
    }
    if (avStreamIndex == -1) {
        NSLog(@"Not find video stream");
        return NULL;
    }else {
        return avStreamIndex;
    }
}

static int AVStreamFPSTimeBase(AVStream *st) {
    CGFloat fps, timebase = 0.0;
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    return fps;
}

- (CGSize)getVideoSize {
    return CGSizeMake(m_video_width, m_video_height);
}

- (void)startParseGetAVPackeWithCompletionHandler:(void (^)(BOOL isVideoFrame, BOOL isFinish, AVPacket packet))handler {
    [self startParseGetAVPacketWithFormatContext:m_formatContext
                                videoStreamIndex:m_videoStreamIndex
                                audioStreamIndex:m_audioStreamIndex
                               completionHandler:handler];
}

- (void)startParseGetAVPacketWithFormatContext:(AVFormatContext *)formatContext videoStreamIndex:(int)videoStreamIndex audioStreamIndex:(int)audioStreamIndex completionHandler:(void (^)(BOOL isVideoFrame, BOOL isFinish, AVPacket packet))handler{
    m_isStopParse = NO;
    dispatch_queue_t parseQueue = dispatch_queue_create("parse_queue", DISPATCH_QUEUE_SERIAL);
    dispatch_async(parseQueue, ^{
        AVPacket    packet;
        while (!self->m_isStopParse) {
            if (!formatContext) {
                break;
            }
            av_init_packet(&packet);
            int size = av_read_frame(formatContext, &packet);
            if (size < 0 || packet.size < 0) {
                handler(YES, YES, packet);
                NSLog(@"Parse finish");
                break;
            }
            if (packet.stream_index == videoStreamIndex) {
                handler(YES, NO, packet);
            }else {
                handler(NO, NO, packet);
            }
            av_packet_unref(&packet);
        }
        [self freeAllResources];
    });
}

- (void)freeAllResources {
    if (m_formatContext) {
        avformat_close_input(&m_formatContext);
        m_formatContext = NULL;
    }
    NSLog(@"Free all resources");
}

- (void)initDecoder {

    // video stream
    AVStream *videoStream = m_formatContext->streams[m_videoStreamIndex];
    
    // video codec content
    m_videoCodecContext = [self createVideoEncderWithFormatContext:m_formatContext stream:videoStream videoStreamIndex:m_videoStreamIndex];
    
    // video frame
    m_videoFrame = av_frame_alloc();
    if (!m_videoFrame) {
        avcodec_close(m_videoCodecContext);
        NSLog(@"alloc video framex failed");
    }
}

- (AVCodecContext *)createVideoEncderWithFormatContext:(AVFormatContext *)formatContext stream:(AVStream *)stream videoStreamIndex:(int)videoStreamIndex {
    
    AVCodecContext *codecContext = NULL;
    AVCodec *codec = NULL;
    
    const char *codecName = av_hwdevice_get_type_name(AV_HWDEVICE_TYPE_VIDEOTOOLBOX);
    enum AVHWDeviceType type = av_hwdevice_find_type_by_name(codecName);
    
    av_find_best_stream(formatContext, AVMEDIA_TYPE_VIDEO, -1, -1, &codec, 0);
    
    codecContext = avcodec_alloc_context3(codec);
    
    avcodec_parameters_to_context(codecContext, formatContext->streams[videoStreamIndex]->codecpar);

    createHardwareDecoder(codecContext, type);
    
    avcodec_open2(codecContext, codec, NULL);
    
    return codecContext;
}

AVBufferRef *hw_device_ctx = NULL;
static int createHardwareDecoder(AVCodecContext *ctx, const enum AVHWDeviceType type) {
    int err = av_hwdevice_ctx_create(&hw_device_ctx, type, NULL, NULL, 0);
    ctx->hw_device_ctx = av_buffer_ref(hw_device_ctx);
    return err;
}

- (void)startDecodeVideoDataWithAVPacket:(AVPacket)packet {
    if (packet.flags == 1 && m_isFindIDR == NO) {
        m_isFindIDR = YES;
        m_base_time =  m_videoFrame->pts;
    }
    
    if (m_isFindIDR == YES) {
        [self startDecodeVideoDataWithAVPacket:packet
                             videoCodecContext:m_videoCodecContext
                                    videoFrame:m_videoFrame
                                      baseTime:m_base_time
                              videoStreamIndex:m_videoStreamIndex];
    }
}

- (void)startDecodeVideoDataWithAVPacket:(AVPacket)packet videoCodecContext:(AVCodecContext *)videoCodecContext videoFrame:(AVFrame *)videoFrame baseTime:(int64_t)baseTime videoStreamIndex:(int)videoStreamIndex {
    
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    Float64 current_timestamp = CMTimeGetSeconds(hostTime);
    
    AVStream *videoStream = m_formatContext->streams[videoStreamIndex];
    int fps = DecodeGetAVStreamFPSTimeBase(videoStream);
    
    avcodec_send_packet(videoCodecContext, &packet);
    while (0 == avcodec_receive_frame(videoCodecContext, videoFrame))
    {
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)videoFrame->data[3];
        CMTime presentationTimeStamp = kCMTimeInvalid;
        int64_t originPTS = videoFrame->pts;
        int64_t newPTS    = originPTS - baseTime;
        presentationTimeStamp = CMTimeMakeWithSeconds(current_timestamp + newPTS * av_q2d(videoStream->time_base) , fps);
        CMSampleBufferRef sampleBufferRef = [self convertCVImageBufferRefToCMSampleBufferRef:(CVPixelBufferRef)pixelBuffer
                                                                   withPresentationTimeStamp:presentationTimeStamp];
        
        if (sampleBufferRef) {
            if ([self.delegate respondsToSelector:@selector(getDecodeVideoDataByFFmpeg:)]) {
                [self.delegate getDecodeVideoDataByFFmpeg:sampleBufferRef];
            }
            
            CFRelease(sampleBufferRef);
        }
    }
}

static int DecodeGetAVStreamFPSTimeBase(AVStream *st) {
    CGFloat fps, timebase = 0.0;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    return fps;
}

- (CMSampleBufferRef)convertCVImageBufferRefToCMSampleBufferRef:(CVImageBufferRef)pixelBuffer withPresentationTimeStamp:(CMTime)presentationTimeStamp {
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    CMSampleBufferRef newSampleBuffer = NULL;
    OSStatus res = 0;
    
    CMSampleTimingInfo timingInfo;
    timingInfo.duration              = kCMTimeInvalid;
    timingInfo.decodeTimeStamp       = presentationTimeStamp;
    timingInfo.presentationTimeStamp = presentationTimeStamp;
    
    CMVideoFormatDescriptionRef videoInfo = NULL;
    res = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    if (res != 0) {
        NSLog(@"Create video format description failed!");
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
    }
    
    res = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,
                                             pixelBuffer,
                                             true,
                                             NULL,
                                             NULL,
                                             videoInfo,
                                             &timingInfo, &newSampleBuffer);
    
    CFRelease(videoInfo);
    if (res != 0) {
        NSLog(@"Create sample buffer failed!");
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return NULL;
        
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    return newSampleBuffer;
}

- (void)stopDecoder {
    [self freeAllResources];
}



@end
