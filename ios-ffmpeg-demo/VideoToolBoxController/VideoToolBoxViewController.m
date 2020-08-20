//
//  VideoToolBoxRecordH264ViewController.m
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/19.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import "VideoToolBoxViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <VideoToolbox/VideoToolbox.h>
#import "VPVideoStreamPlayLayer.h"

static NSString *const H264FilePath = @"videoToolBoxH264File.h264";

static const uint8_t startCode[4] = {0, 0, 0, 1};

@interface VideoToolBoxViewController ()
{
    //帧号
    int frameNO;
    
    //编码队列
    dispatch_queue_t encodeQueue;
    
    //编码 session
    VTCompressionSessionRef encodingSession;
}



@property (nonatomic,strong)NSFileHandle *h264FileHandle; //句柄


@property (nonatomic, strong) NSInputStream *inputStream;
@property (nonatomic , strong) CADisplayLink *dispalyLink;
@property (nonatomic, strong) VPVideoStreamPlayLayer *playLayer;

@end

@implementation VideoToolBoxViewController {
    VTDecompressionSessionRef _decodeSession;
    CMFormatDescriptionRef  _formatDescription;
    uint8_t *_sps;
    long _spsSize;
    uint8_t *_pps;
    long _ppsSize;
    
    uint8_t *_packetBuffer;
    long _packetSize;
    uint8_t *_inputBuffer;
    long _inputSize;
    long _inputMaxSize;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    self.title = @"VideoToolBox";

    encodeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

    CGFloat height = self.view.frame.size.width /2160 * 3840;
    CGRect frame = CGRectMake(0, 0, self.view.frame.size.width, height);
    VPVideoStreamPlayLayer *layer = [[VPVideoStreamPlayLayer alloc] initWithFrame:frame];
    [self.view.layer insertSublayer:layer atIndex:0];
    self.playLayer = layer;
    self.playLayer.hidden = YES;
}

- (void)startCaputureSession {
    
    [self initVideoToolBox];
    [self configFileHandle];

    [super startCaputureSession];
    
    
    self.playLayer.hidden = YES;
}


- (void)endCaputureSession {
    [super endCaputureSession];
    
    //停止采集
    [self EndVideoToolBox];
    [self closeFileHandle];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        
        NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:H264FilePath];//
        UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:@[[NSURL fileURLWithPath:filePath]] applicationActivities:nil];
        [self presentViewController:activityVC animated:YES completion:nil];
        
        self.playLayer.hidden = NO;
        [self initInputFile];
        self.dispalyLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(startDecode)];
        self.dispalyLink.frameInterval = 2; // 默认是30FPS的帧率录制
        [self.dispalyLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    });
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    dispatch_sync(encodeQueue, ^{
        [self encode:sampleBuffer];
    });
}


#pragma mark - VideoToolBox编码
- (void)initVideoToolBox {
    dispatch_sync(encodeQueue  , ^{
        frameNO = 0;
        
//        3840x2160;
        int width = 2160, height = 3840;
        OSStatus status = VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, didCompressH264, (__bridge void *)(self),  &encodingSession);
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        if (status != 0)
        {
            NSLog(@"H264: Unable to create a H264 session");
            return ;
        }
        
        // 设置实时编码输出（避免延迟）
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        
        // 设置关键帧间隔
        int frameInterval = 24;
        CFNumberRef  frameIntervalRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &frameInterval);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, frameIntervalRef);
        
        //设置期望帧率
        int fps = 24;
        CFNumberRef  fpsRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_ExpectedFrameRate, fpsRef);
        
        //设置码率，均值，单位是byte
        int bitRate = width * height * 3 * 4 * 80;
        CFNumberRef bitRateRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRate);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_AverageBitRate, bitRateRef);
        
        //设置码率，上限，单位是bps
        int bitRateLimit = width * height * 3 * 4 * 80;
        CFNumberRef bitRateLimitRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &bitRateLimit);
        VTSessionSetProperty(encodingSession, kVTCompressionPropertyKey_DataRateLimits, bitRateLimitRef);
        
        //开始编码
        VTCompressionSessionPrepareToEncodeFrames(encodingSession);
    });
}

//编码sampleBuffer
- (void)encode:(CMSampleBufferRef )sampleBuffer
{
    CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
    // 帧时间，如果不设置会导致时间轴过长。
    CMTime presentationTimeStamp = CMTimeMake(frameNO++, 1000);
    VTEncodeInfoFlags flags;
    OSStatus statusCode = VTCompressionSessionEncodeFrame(encodingSession,
                                                          imageBuffer,
                                                          presentationTimeStamp,
                                                          kCMTimeInvalid,
                                                          NULL, NULL, &flags);
    if (statusCode != noErr) {
        NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
        
        VTCompressionSessionInvalidate(encodingSession);
        CFRelease(encodingSession);
        encodingSession = NULL;
        return;
    }
    NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
}

// 编码完成回调
void didCompressH264(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer) {
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) {
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    VideoToolBoxViewController* encoder = (__bridge VideoToolBoxViewController*)outputCallbackRefCon;
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    // 判断当前帧是否为关键帧
    // 获取sps & pps数据
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // 获得了sps，再获取pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // 获取SPS和PPS data
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder)
                {
                    [encoder gotSpsPps:sps pps:pps];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    
    //这里获取了数据指针，和NALU的帧总长度，前四个字节里面保存的
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4; // 返回的nalu数据前四个字节不是0001的startcode，而是大端模式的帧长度length
        
        // 循环获取nalu数据
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            uint32_t NALUnitLength = 0;
            // 读取NALU长度的数据
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // 从大端转系统端
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder gotEncodedData:data];
            
            // 移动到下一个NALU单元
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
    }
}

//填充SPS和PPS数据
- (void)gotSpsPps:(NSData*)sps pps:(NSData*)pps
{
    NSLog(@"gotSpsPps %d %d", (int)[sps length], (int)[pps length]);
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [self.h264FileHandle writeData:ByteHeader];
    [self.h264FileHandle writeData:sps];
    [self.h264FileHandle writeData:ByteHeader];
    [self.h264FileHandle writeData:pps];
    
}

//填充NALU数据
- (void)gotEncodedData:(NSData*)data
{
    NSLog(@"gotEncodedData %d", (int)[data length]);
    if (self.h264FileHandle != NULL)
    {
        const char bytes[] = "\x00\x00\x00\x01";
        size_t length = (sizeof bytes) - 1; //string literals have implicit trailing '\0'
        NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
        [self.h264FileHandle writeData:ByteHeader];
        [self.h264FileHandle writeData:data];
    }
}

- (void)EndVideoToolBox
{
    VTCompressionSessionCompleteFrames(encodingSession, kCMTimeInvalid);
    VTCompressionSessionInvalidate(encodingSession);
    CFRelease(encodingSession);
    encodingSession = NULL;
}



- (void)configFileHandle{
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:H264FilePath];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    //文件存在的话先删除文件
    if ([fileManager fileExistsAtPath:filePath]) {
        [fileManager removeItemAtPath:filePath error:nil];
    }
    [fileManager createFileAtPath:filePath contents:nil attributes:nil];
    self.h264FileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
}


- (void)closeFileHandle{
    if (self.h264FileHandle) {
        [self.h264FileHandle closeFile];
        self.h264FileHandle = nil;
    }
}

- (void)initInputFile
{
    NSString *filePath = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:H264FilePath];
    
    self.inputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    [self.inputStream open];
    _inputSize = 0;
    _inputMaxSize = 5000000;
    _inputBuffer = calloc(_inputMaxSize, 1);
}

- (void)inputEnd {
    [self.inputStream close];
    self.inputStream = nil;
    if (_inputBuffer) {
        free(_inputBuffer);
        _inputBuffer = NULL;
    }
    [self.dispalyLink setPaused:YES];

    
}

- (void)initVideoToolbox
{
    // 根据sps pps创建解码视频参数
    CMFormatDescriptionRef fmtDesc;
    const uint8_t* parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault,
                                                                          2, //param count
                                                                          parameterSetPointers,
                                                                          parameterSetSizes,
                                                                          4, //nal start code size
                                                                          &fmtDesc);
    if (status != noErr) {
        NSLog(@"IOS8VT: reset decoder session failed status=%d", status);
        return;
    }
    
    if (_decodeSession == nil || !VTDecompressionSessionCanAcceptFormatDescription(_decodeSession, fmtDesc)) {
        if (_decodeSession) {
            VTDecompressionSessionInvalidate(_decodeSession);
            CFRelease(_decodeSession);
            _decodeSession = nil;
        }
        if (_formatDescription) {
            CFRelease(_formatDescription);
        }
        
        _formatDescription = fmtDesc;
        
        CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions(_formatDescription);
        NSDictionary *attrs = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
                                (id)kCVPixelBufferWidthKey : @(dimensions.width),
                                (id)kCVPixelBufferHeightKey : @(dimensions.height),
                                };
        
        //设置回调
        VTDecompressionOutputCallbackRecord callBackRecord;
        callBackRecord.decompressionOutputCallback = decodeOutputDataCallback;
        callBackRecord.decompressionOutputRefCon = (__bridge void *)self;
        
        status = VTDecompressionSessionCreate(kCFAllocatorDefault,
                                              _formatDescription,
                                              NULL, (__bridge CFDictionaryRef)attrs,
                                              &callBackRecord,
                                              &_decodeSession);
        // 解码线程数量
        VTSessionSetProperty(_decodeSession, kVTDecompressionPropertyKey_ThreadCount, (__bridge CFTypeRef)@(1));
        // 是否实时解码
        VTSessionSetProperty(_decodeSession, kVTDecompressionPropertyKey_RealTime, kCFBooleanTrue);
    }else {
        CFRelease(fmtDesc);
    }


    
}

- (void)startDecode
{
    [self readPacket];
    if(_packetBuffer == NULL || _packetSize == 0) {
        [self inputEnd];
        return;
    }
    
    //将NALU的开始码替换成NALU的长度信息，长度固定4个字节
    uint32_t nalSize = (uint32_t)(_packetSize - 4);
    uint32_t *pNalSize = (uint32_t *)_packetBuffer;
    *pNalSize = CFSwapInt32HostToBig(nalSize);
    
    int nalType = _packetBuffer[4] & 0x1F;
    switch (nalType) {
        case 0x05:
            NSLog(@"Nal type is IDR frame");
            [self initVideoToolbox];
            [self decode];
            break;
        case 0x07:
            NSLog(@"Nal type is SPS");
            if (_sps) {
                free(_sps);
                _sps = NULL;
            }
            _spsSize = _packetSize - 4;
            _sps = malloc(_spsSize);
            memcpy(_sps, _packetBuffer + 4, _spsSize);
            break;
        case 0x08:
            NSLog(@"Nal type is PPS");
            if (_pps) {
                free(_pps);
                _pps = NULL;
            }
            _ppsSize = _packetSize - 4;
            _pps = malloc(_ppsSize);
            memcpy(_pps, _packetBuffer + 4, _ppsSize);
            break;
        default:
            NSLog(@"Nal type is B/P frame");
            [self decode];
            break;
    }

    NSLog(@"Read Nalu size %ld", _packetSize);
    
}
- (void)decode
{
    CMBlockBufferRef blockBuffer = NULL;
    // 创建 CMBlockBufferRef
    OSStatus status  = CMBlockBufferCreateWithMemoryBlock(NULL, (void*)_packetBuffer, _packetSize, kCFAllocatorNull, NULL, 0, _packetSize, 0, &blockBuffer);
    if(status != kCMBlockBufferNoErr)
    {
        return;
    }
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {_packetSize};
    // 创建 CMSampleBufferRef
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, _formatDescription , 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    if (status != kCMBlockBufferNoErr || sampleBuffer == NULL)
    {
        return;
    }
    // VTDecodeFrameFlags 0为允许多线程解码
    VTDecodeFrameFlags flags = 0;
    VTDecodeInfoFlags flagOut = 0;
    // 解码 这里第四个参数会传到解码的callback里的sourceFrameRefCon，可为空
    OSStatus decodeStatus = VTDecompressionSessionDecodeFrame(_decodeSession, sampleBuffer, flags, NULL, &flagOut);
    
    if(decodeStatus == kVTInvalidSessionErr)
    {
        NSLog(@"H264Decoder::Invalid session, reset decoder session");
    }
    else if(decodeStatus == kVTVideoDecoderBadDataErr)
    {
        NSLog(@"H264Decoder::decode failed status = %d(Bad data)", (int)decodeStatus);
    }
    else if(decodeStatus != noErr)
    {
        NSLog(@"H264Decoder::decode failed status = %d", (int)decodeStatus);
    }
    // Create了就得Release
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
}

- (void)readPacket {
    if (_packetSize && _packetBuffer) {
        _packetSize = 0;
        free(_packetBuffer);
        _packetBuffer = NULL;
    }
    if (_inputSize < _inputMaxSize && self.inputStream.hasBytesAvailable) {
        _inputSize += [self.inputStream read:_inputBuffer + _inputSize maxLength:_inputMaxSize - _inputSize];
    }
    if (memcmp(_inputBuffer, startCode, 4) == 0) {
        if (_inputSize > 4) {
            uint8_t *pStart = _inputBuffer + 4;
            uint8_t *pEnd = _inputBuffer + _inputSize;
            while (pStart != pEnd) {
                if(memcmp(pStart - 3, startCode, 4) == 0) {
                    _packetSize = pStart - _inputBuffer - 3;
                    if (_packetBuffer) {
                        free(_packetBuffer);
                        _packetBuffer = NULL;
                    }
                    _packetBuffer = calloc(_packetSize, 1);
                    memcpy(_packetBuffer, _inputBuffer, _packetSize); //复制packet内容到新的缓冲区
                    memmove(_inputBuffer, _inputBuffer + _packetSize, _inputSize - _packetSize); //把缓冲区前移
                    _inputSize -= _packetSize;
                    break;
                }
                else {
                    ++pStart;
                }
            }
        }
    }
}

static void decodeOutputDataCallback(void *decompressionOutputRefCon, void *sourceFrameRefCon, OSStatus status, VTDecodeInfoFlags infoFlags, CVImageBufferRef pixelBuffer, CMTime presentationTimeStamp, CMTime presentationDuration)
{
    CVPixelBufferRetain(pixelBuffer);
    VideoToolBoxViewController *vc = (__bridge VideoToolBoxViewController *)decompressionOutputRefCon;
    [vc.playLayer inputPixelBuffer:pixelBuffer];
    CVPixelBufferRelease(pixelBuffer);

}


@end

