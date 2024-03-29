//
//  WCLRecordEncoder.m
//  WCL
//
// **************************************************
// *                                  _____         *
// *         __  _  __     ___        \   /         *
// *         \ \/ \/ /    / __\       /  /          *
// *          \  _  /    | (__       /  /           *
// *           \/ \/      \___/     /  /__          *
// *                               /_____/          *
// *                                                *
// **************************************************
//  Github  :https://github.com/631106979
//  HomePage:https://imwcl.com
//  CSDN    :http://blog.csdn.net/wang631106979
//
//  Created by 王崇磊 on 16/9/14.
//  Copyright © 2016年 王崇磊. All rights reserved.
//
// @class WCLRecordEncoder
// @abstract 视频编码类
// @discussion 应用的相关扩展
//
// 博客地址：http://blog.csdn.net/wang631106979/article/details/51498009

#import "WCLRecordEncoder.h"

@interface WCLRecordEncoder ()

@property (nonatomic, strong) AVAssetWriter *writer;//媒体写入对象
@property (nonatomic, strong) AVAssetWriterInput *videoInput;//视频写入
@property (nonatomic, strong) AVAssetWriterInput *audioInput;//音频写入
@property (nonatomic, strong) NSString *path;//写入路径

@end

@implementation WCLRecordEncoder

- (void)dealloc {
    _writer = nil;
    _videoInput = nil;
    _audioInput = nil;
    _path = nil;
}

//WCLRecordEncoder遍历构造器的
+ (WCLRecordEncoder*)encoderForPath:(NSString*) path Height:(NSInteger) cy width:(NSInteger) cx channels: (int) ch samples:(Float64) rate {
    WCLRecordEncoder* enc = [WCLRecordEncoder alloc];
    return [enc initPath:path Height:cy width:cx channels:ch samples:rate];
}
//初始化方法
- (instancetype)initPath:(NSString*)path{
    self = [super init];
    if (self) {
        self.path = path;
        //先把路径下的文件给删除掉，保证录制的文件是最新的
        [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
        NSURL* url = [NSURL fileURLWithPath:self.path];
        //初始化写入媒体类型为MP4类型
        _writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:nil];
        //使其更适合在网络上播放
        _writer.shouldOptimizeForNetworkUse = YES;
    }
    return self;
}
//初始化方法
- (instancetype)initPath:(NSString*)path Height:(NSInteger)cy width:(NSInteger)cx channels:(int)ch samples:(Float64) rate {
    self = [super init];
    if (self) {
        self.path = path;
        //先把路径下的文件给删除掉，保证录制的文件是最新的
        [[NSFileManager defaultManager] removeItemAtPath:self.path error:nil];
        NSURL* url = [NSURL fileURLWithPath:self.path];
        //初始化写入媒体类型为MP4类型
        _writer = [AVAssetWriter assetWriterWithURL:url fileType:AVFileTypeMPEG4 error:nil];
        //使其更适合在网络上播放
        _writer.shouldOptimizeForNetworkUse = YES;
        //初始化视频输出
        [self initVideoInputHeight:cy width:cx];
        //确保采集到rate和ch
        if (rate != 0 && ch != 0) {
            //初始化音频输出
            [self initAudioInputChannels:ch samples:rate];
        }
    }
    return self;
}
//int numPixels = dimensions.width * dimensions.height;
//int bitsPerSecond;
//
//NSLog( @"No video settings provided, using default settings" );
//
//// Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
//if ( numPixels < ( 640 * 480 ) ) {
//    bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
//}
//else {
//    bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
//}
//
//bitsPerSecond = numPixels * bitsPerPixel;
//NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
//                                         AVVideoExpectedSourceFrameRateKey : @(30),
//                                         AVVideoMaxKeyFrameIntervalKey : @(30) };
//
//_videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
//                   AVVideoWidthKey : @(dimensions.width),
//                   AVVideoHeightKey : @(dimensions.height),
//                   AVVideoCompressionPropertiesKey : compressionProperties };
//初始化视频输入
- (void)initVideoInputHeight:(NSInteger)cy width:(NSInteger)cx {
//    int numPixels = cx * cy;
//    int bitsPerSecond;
//    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
//    if ( numPixels < ( 640 * 480 ) ) {
//        bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
//    }
//    else {
//        bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
//    }
//
//    bitsPerSecond = numPixels * bitsPerPixel;
    //录制视频的一些配置，分辨率，编码方式等等
    NSDictionary* settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              AVVideoCodecH264, AVVideoCodecKey,
                              [NSNumber numberWithInteger: cx], AVVideoWidthKey,
                              [NSNumber numberWithInteger: cy], AVVideoHeightKey,
                              nil];
    //初始化视频写入类
    _videoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:settings];
    //表明输入是否应该调整其处理为实时数据源的数据
    _videoInput.expectsMediaDataInRealTime = YES;
    //将视频输入源加入
    [_writer addInput:_videoInput];
}

//初始化音频输入
- (void)initAudioInputChannels:(int)ch samples:(Float64)rate {
    //音频的一些配置包括音频各种这里为AAC,音频通道、采样率和音频的比特率
    NSDictionary *settings = [NSDictionary dictionaryWithObjectsAndKeys:
                              [ NSNumber numberWithInt: kAudioFormatMPEG4AAC], AVFormatIDKey,
                              [ NSNumber numberWithInt: ch], AVNumberOfChannelsKey,
                              [ NSNumber numberWithFloat: rate], AVSampleRateKey,
                              [ NSNumber numberWithInt: 128000], AVEncoderBitRateKey,
                              nil];
    //初始化音频写入类
    _audioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:settings];
    //表明输入是否应该调整其处理为实时数据源的数据
    _audioInput.expectsMediaDataInRealTime = YES;
    //将音频输入源加入
    [_writer addInput:_audioInput];
    
}

//完成视频录制时调用
- (void)finishWithCompletionHandler:(void (^)(void))handler {
    [_writer finishWritingWithCompletionHandler: handler];
}

//通过这个方法写入数据
- (BOOL)encodeFrame:(CMSampleBufferRef) sampleBuffer isVideo:(BOOL)isVideo {
    //数据是否准备写入
    if (CMSampleBufferDataIsReady(sampleBuffer)) {
        //写入状态为未知,保证视频先写入
        if (_writer.status == AVAssetWriterStatusUnknown && isVideo) {
            //获取开始写入的CMTime
            CMTime startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            //开始写入
            [_writer startWriting];
            [_writer startSessionAtSourceTime:startTime];
        }
        //写入失败
        if (_writer.status == AVAssetWriterStatusFailed) {
            NSLog(@"writer error %@", _writer.error.localizedDescription);
            return NO;
        }
        //判断是否是视频
        if (isVideo) {
            //视频输入是否准备接受更多的媒体数据
            if (_videoInput.readyForMoreMediaData == YES) {
                //拼接数据
                [_videoInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        }else {
            //音频输入是否准备接受更多的媒体数据
            if (_audioInput.readyForMoreMediaData) {
                //拼接数据
                [_audioInput appendSampleBuffer:sampleBuffer];
                return YES;
            }
        }
    }
    return NO;
}

@end
