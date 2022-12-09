//
//  CicadaPlayerViewController.m
//  CicadaPlayerDemo
//
//  Created by 郦立 on 2019/1/2.
//  Copyright © 2019年 com.alibaba. All rights reserved.
//

#import "CicadaPlayerViewController.h"
#import "CicadaDemoView.h"
#import "CicadaSettingAndConfigView.h"
#import "UIView+AVPFrame.h"
#import "CicadaConfig+refresh.h"
#import "CicadaCacheConfig+refresh.h"
#import "AppDelegate.h"
#import "UIViewController+backAction.h"
#import "CicadaShowImageView.h"
#import "CicadaErrorModel+string.h"
#import "AFNetworking.h"
#import <AVFoundation/AVFoundation.h>
#import <Photos/Photos.h>
#import "WCLRecordEncoder.h"


#define VIDEO_FILEPATH                                              @"video"

@interface CicadaPlayerViewController ()<CicadaDemoViewDelegate,CicadaSettingAndConfigViewDelegate,CicadaDelegate,CicadaAudioSessionDelegate, CicadaRenderDelegate>
{
    CMFormatDescriptionRef _audioTrackSourceFormatDescription;
    CMTime _timeOffset;//录制的偏移CMTime
    CMTime _lastVideo;//记录上一次视频数据文件的CMTime
    CMTime _lastAudio;//记录上一次音频数据文件的CMTime
    
    NSInteger _cx;//视频分辨的宽
    NSInteger _cy;//视频分辨的高
    int _channels;//音频通道
    Float64 _samplerate;//音频采样率
}
/**
 播放视图
 */
@property (nonatomic,strong)CicadaDemoView *CicadaView;

/**
 底部tab选择视图
 */
@property (nonatomic,strong)CicadaSettingAndConfigView *settingAndConfigView;

/**
 播放器
 */
@property (nonatomic,strong)CicadaPlayer *player;

/**
 当前Track是否有缩略图，如果没有，不展示缩略图
 */
@property (nonatomic,assign)BOOL trackHasThumbnai;

/**
 记录当前网络类型
 */
@property (nonatomic,assign)AFNetworkReachabilityStatus currentNetworkStatus;

/**
 记录流量网络是否重试
 */
@property (nonatomic,assign)BOOL wanWillRetry;

/**
 剩余重试次数
*/
@property (nonatomic,assign)NSInteger retryCount;

/**
 记录是否完成viewdidload,防止还没完成添加，返回界面，移除空观察者造成的崩溃
 */
@property (nonatomic,assign)BOOL isViewDidLoad;

/**
当前的外挂字幕的Index
*/
@property (nonatomic,assign)int extSubtitleTrackIndex;

/**
点击准备时，需要调用stop
*/
@property (nonatomic,assign)BOOL needStop;

/**
混音播放
*/
@property (nonatomic,assign)BOOL enableMix;


@property (nonatomic, strong)WCLRecordEncoder * recordEncoder;//录制编码
@property (copy, nonatomic) dispatch_queue_t           captureQueue;//录制的队列
@property (atomic, assign) BOOL isCapturing;//正在录制
@property (atomic, assign) BOOL isPaused;//是否暂停
@property (atomic, assign) BOOL discont;//是否中断
@property (atomic, assign) CMTime startTime;//开始录制的时间
@property (atomic, assign) CGFloat currentRecordTime;//当前录制时间
@property (nonatomic, strong)UIButton * recordBtn;
@property (nonatomic, strong) NSDictionary *videoCompressionSettings;
@property (nonatomic, strong) NSDictionary *audioCompressionSettings;
@property(nonatomic, strong) NSURL * recordingURL;
@end

@implementation CicadaPlayerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSURL *url = [NSURL fileURLWithPath:[self createVideoFilePath]];
    _recordingURL = url;
    NSLog(@"录像地址:%@", _recordingURL);
    
    self.retryCount = 3;
#if !TARGET_OS_MACCATALYST
    [self setScreenCanRotation:YES];
#endif
    self.view.backgroundColor = [UIColor whiteColor];
    self.navigationItem.title = NSLocalizedString(@"播放" , nil);
    
    //禁止手势返回
    if ([self.navigationController respondsToSelector:@selector(interactivePopGestureRecognizer)]) {
        self.navigationController.interactivePopGestureRecognizer.enabled = NO;
    }

    CGFloat screenW = SCREEN_WIDTH;
    CGFloat screenH = SCREEN_HEIGHT;

#if TARGET_OS_MACCATALYST
    screenW = CGRectGetWidth(self.view.frame);
    screenH = CGRectGetHeight(self.view.frame);
#endif
    
    
    
    self.CicadaView = [[CicadaDemoView alloc] initWithFrame:CGRectMake(0, NAVIGATION_HEIGHT, screenW, screenW / 16 * 9 + 44)];
    self.CicadaView.delegate = self;
    [self.view addSubview:self.CicadaView];
    
    self.recordBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.recordBtn setTitle:@"开始录像" forState:UIControlStateNormal];
    [self.recordBtn setTitle:@"结束录像" forState:UIControlStateSelected];
    [self.recordBtn addTarget:self action:@selector(recordClick:) forControlEvents:UIControlEventTouchUpInside];
    self.recordBtn.frame = CGRectMake((screenW-60) / 2, self.CicadaView.getMaxY, 100, 40);
    [self.view addSubview:self.recordBtn];

    self.settingAndConfigView = [[CicadaSettingAndConfigView alloc]
            initWithFrame:CGRectMake(0, self.recordBtn.getMaxY, screenW, screenH - self.CicadaView.getMaxY - SAFE_BOTTOM)];
    self.settingAndConfigView.delegate = self;
    NSMutableArray *configArray = [CicadaTool getCicadaConfigArray];
    [self.settingAndConfigView setIshardwareDecoder:[CicadaTool isHardware]];
    [self.settingAndConfigView setConfigArray:configArray];
    [self.view addSubview:self.settingAndConfigView];

#if TARGET_OS_MACCATALYST
    self.settingAndConfigView.hidden = CGRectGetWidth(self.view.frame) > MACCATALYST_WIDTH;
#endif

    [CicadaPlayer setAudioSessionDelegate:self];
    if (self.useFairPlay) {
        self.player = [[CicadaPlayer alloc] init:nil opt:@{@"name":@"AppleAVPlayer"}];
        [self.player performSelector:@selector(setAVResourceLoaderDelegate:) withObject:self.avResourceLoaderDelegate];
    } else {
        self.player = [[CicadaPlayer alloc] init];
    }
    
    self.player.enableHardwareDecoder = [CicadaTool isHardware];
    self.player.playerView = self.CicadaView.playerView;
    self.player.delegate = self;
    //enable to test render delegate
    self.player.renderDelegate = self;
    self.player.scalingMode = CICADA_SCALINGMODE_SCALEASPECTFIT;
    [self.settingAndConfigView setVolume:self.player.volume/2];
    [self setConfig];

#if !TARGET_OS_MACCATALYST
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(orientationDidChangeFunc) name:UIDeviceOrientationDidChangeNotification object:nil];
#endif

    // 添加检测app进入后台的观察者
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationEnterBackground)
                                                 name:UIApplicationDidEnterBackgroundNotification
                                               object:nil];
    // app从后台进入前台都会调用这个方法
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationWillEnterForegroundNotification
                                               object:nil];

    WEAK_SELF
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        if (weakSelf.retryCount == 0) {
            [weakSelf.player reload];
        }else if (status == AFNetworkReachabilityStatusReachableViaWWAN) {
            //切换到流量
            [CicadaPlayer netWorkReConnect];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:NSLocalizedString(@"当前为流量网络，是否继续?" , nil) preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction *sureAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"确认" , nil) style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                weakSelf.wanWillRetry = YES;
            }];
            [alert addAction:sureAction];
            UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:NSLocalizedString(@"取消" , nil) style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                weakSelf.wanWillRetry = NO;
            }];
            [alert addAction:cancelAction];
            [weakSelf presentViewController:alert animated:YES completion:nil];
        }else if(status == AFNetworkReachabilityStatusReachableViaWiFi){
            [CicadaPlayer netWorkReConnect];
        }
        weakSelf.currentNetworkStatus = status;
    }];

    [self.player addObserver:self
                  forKeyPath:@"width"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
    [self.player addObserver:self
                  forKeyPath:@"height"
                     options:NSKeyValueObservingOptionNew
                     context:nil];
    self.isViewDidLoad = YES;
}

// whenever an observed key path changes, this method will be called
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context
{
    NSNumber* value = [self.player valueForKeyPath:keyPath];
    NSLog(@"keyPath:%@, value:%@, change:%@", keyPath, value, change);
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    if (self.isViewDidLoad) {
        [self.player removeObserver:self forKeyPath:@"width"];
        [self.player removeObserver:self forKeyPath:@"height"];
    }
    [self.player stop];
    [self.player destroy];
    [CicadaPlayer setAudioSessionDelegate:nil];
#if !TARGET_OS_MACCATALYST
    [self setScreenCanRotation:NO];
#endif
}

- (void)setScreenCanRotation:(BOOL)canRotation {
    AppDelegate *deledage = (AppDelegate *)[UIApplication sharedApplication].delegate;
    deledage.allowRotation = canRotation;
}

- (void)orientationDidChangeFunc {
#if !TARGET_OS_MACCATALYST
    if (IS_PORTRAIT) {
        UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
        bool iphonexLeft = (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight);
        if (IS_IPHONEX && iphonexLeft) {
            NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
            [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
        }else {
            self.settingAndConfigView.hidden = NO;
        }
        self.navigationController.navigationBar.hidden = NO;
    }else {
        self.settingAndConfigView.hidden = YES;
        self.navigationController.navigationBar.hidden = YES;
    }
#endif
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.player redraw];
}

- (void)applicationEnterBackground {
#if !TARGET_OS_MACCATALYST
    if (!self.settingAndConfigView.isPlayBackgournd) {
        [self.player pause];
    }
#endif
}

- (void)applicationDidBecomeActive {
#if !TARGET_OS_MACCATALYST
    if (!self.settingAndConfigView.isPlayBackgournd) {
        [self.player start];
    }
#endif
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator
{
#if TARGET_OS_MACCATALYST
    CGFloat screenW = size.width;
    CGFloat screenH = size.height;
    CGFloat duration = [coordinator transitionDuration];
    [UIView animateWithDuration:duration
                     animations:^{
                       if (screenW > MACCATALYST_WIDTH) {
                           self.settingAndConfigView.hidden = YES;
                       } else {
                           self.settingAndConfigView.hidden = NO;
                       }
                       self.CicadaView.frame = CGRectMake(0, NAVIGATION_HEIGHT, screenW, screenW / 16 * 9 + 44);

                       self.settingAndConfigView.frame =
                               CGRectMake(0, self.CicadaView.getMaxY, screenW, screenH - self.CicadaView.getMaxY - SAFE_BOTTOM);
                     }];
#endif
}

#pragma mark navigationPopback

/**
 返回键点击事件

 @return 是否可以返回
 */
- (BOOL)navigationShouldPopOnBackButton{
    //如果竖屏可以返回，如果横屏，先竖屏幕
    if (IS_PORTRAIT || TARGET_OS_MACCATALYST) {
        return YES;
    }
    NSNumber *value = [NSNumber numberWithInt:UIInterfaceOrientationPortrait];
    [[UIDevice currentDevice] setValue:value forKey:@"orientation"];
    return NO;
}

#pragma mark CicadaDemoViewDelegate

/**
 底部按钮点击回调
 
 @param playerView playerView
 @param index 0:准备,1:播放,2:暂停,3:停止,4:截图,5:重试
 */
- (void)CicadaDemoView:(CicadaDemoView *)playerView bottonButtonClickAtIndex:(NSInteger)index {
    NSLog(@"%ld",(long)index);
    switch (index) {
        case 0: {
            [self.settingAndConfigView setIshardwareDecoder:[CicadaTool isHardware]];
            if (self.needStop) {
                [self.player stop];
            }
            self.needStop = YES;
            for (NSString *value in self.subtitleDictionary.allValues) {
                [self.player addExtSubtitle:value];
            }
            if (self.urlSource) {
                [self.player setUrlSource:self.urlSource];
                [self.player prepare];
            }
        }
            break;
        case 1: { [self.player start]; }
            break;
        case 2: { [self.player pause]; }
            break;
        case 3: {
            [self.player stop];
            self.needStop = NO;
            [self.CicadaView hiddenLoadingView];
            self.CicadaView.subTitleLabel.hidden = YES;
            self.CicadaView.bufferPosition = 0;
            self.CicadaView.currentPosition = 0;
            self.CicadaView.allPosition = 0;
        }
            break;
        case 4: {
            [self.player snapShot];
        }
            break;
        case 5: {
            [self.player reload];
        }
            break;
        default:
            break;
    }
}

/**
 全屏按钮点击回调
 
 @param playerView playerView
 @param isFull 是否全屏
 */
- (void)CicadaDemoView:(CicadaDemoView *)playerView fullScreenButtonAction:(BOOL)isFull {
    NSLog(@"%d",isFull);
}

/**
 进度条完成进度回调
 
 @param playerView playerView
 @param value 进度值
 */
- (void)CicadaDemoView:(CicadaDemoView *)playerView progressSliderDidChange:(CGFloat)value {
    NSLog(@"%f",value);
    [self.CicadaView hiddenThumbnailView];
    
    CicadaSeekMode seekMode = CICADA_SEEKMODE_INACCURATE;
    if (self.settingAndConfigView.isAccurateSeek) { seekMode = CICADA_SEEKMODE_ACCURATE; }
    [self.player seekToTime:value*self.player.duration seekMode:seekMode];
}

/**
 进度条改变进度回调
 
 @param playerView playerView
 @param value 进度值
 */
- (void)CicadaDemoView:(CicadaDemoView *)playerView progressSliderValueChanged:(CGFloat)value {
    if (self.trackHasThumbnai) {
        [self.player getThumbnail:self.player.duration*value];
    }
}

#pragma mark CicadaSettingAndConfigViewDelegate

/**
 switch按钮点击回调
 
 @param view settingAndConfigView
 @param index 0:自动播放,1:静音,2:循环,3:硬解码,4:精准seek
 @param isOpen 是否打开
 */
- (void)settingAndConfigView:(CicadaSettingAndConfigView *)view switchChangedIndex:(NSInteger)index isOpen:(BOOL)isOpen {
    NSLog(@"%ld %d",(long)index,isOpen);
    switch (index) {
        case 0: { self.player.autoPlay = isOpen; }
            break;
        case 1: { self.player.muted = isOpen; }
            break;
        case 2: { self.player.loop = isOpen; }
            break;
        case 3: { self.player.enableHardwareDecoder = isOpen; }
            break;
        default:
            break;
    }
}

/**
 声音进度条点击回调
 
 @param view settingAndConfigView
 @param value 进度值
 */
- (void)settingAndConfigView:(CicadaSettingAndConfigView *)view voiceSliderDidChange:(CGFloat)value {
    NSLog(@"%f",value);
    self.player.muted = NO;
    self.player.volume = value * 2;
}

/**
 segmented点击回调
 
 @param view settingAndConfigView
 @param index 0:缩放模式,1:镜像模式,2:旋转模式,3:倍速播放
 @param selectedIndex 选择了第几个seg
 */
- (void)settingAndConfigView:(CicadaSettingAndConfigView *)view segmentedControlIndex:(NSInteger)index selectedIndex:(NSInteger)selectedIndex {
    NSLog(@"%ld %ld",(long)index,(long)selectedIndex);
    switch (index) {
        case 0: {
            switch (selectedIndex) {
                case 0: { self.player.scalingMode = CICADA_SCALINGMODE_SCALEASPECTFIT; }
                    break;
                case 1: { self.player.scalingMode = CICADA_SCALINGMODE_SCALEASPECTFILL; }
                    break;
                case 2: { self.player.scalingMode = CICADA_SCALINGMODE_SCALETOFILL; }
                    break;
                default:
                    break;
            }
        }
            break;
        case 1: {
            switch (selectedIndex) {
                case 0: { self.player.mirrorMode = CICADA_MIRRORMODE_NONE; }
                    break;
                case 1: { self.player.mirrorMode = CICADA_MIRRORMODE_HORIZONTAL; }
                    break;
                case 2: { self.player.mirrorMode = CICADA_MIRRORMODE_VERTICAL; }
                    break;
                default:
                    break;
            }
        }
            break;
        case 2: {
            switch (selectedIndex) {
                case 0: { self.player.rotateMode = CICADA_ROTATE_0; }
                    break;
                case 1: { self.player.rotateMode = CICADA_ROTATE_90; }
                    break;
                case 2: { self.player.rotateMode = CICADA_ROTATE_180; }
                    break;
                case 3: { self.player.rotateMode = CICADA_ROTATE_270; }
                    break;
                default:
                    break;
            }
        }
            break;
        case 3: {
            switch (selectedIndex) {
                case 0: { self.player.rate = 1; }
                    break;
                case 1: { self.player.rate = 0.5; }
                    break;
                case 2: { self.player.rate = 1.5; }
                    break;
                case 3: { self.player.rate = 2; }
                    break;
                default:
                    break;
            }
        }
            break;
        default:
            break;
    }
}

- (void)setConfig {
    NSArray *configArray = [self.settingAndConfigView getConfigArray];
    CicadaConfig *config = [self.player getConfig];
    [config refreshConfigWithArray:configArray];
    [self.player setConfig:config];
}

- (void)setCacheConfig {
    NSDictionary *cacheDic = [self.settingAndConfigView getCacheConfigDictionary];
    CicadaCacheConfig *config = [[CicadaCacheConfig alloc]init];
    [config refreshConfigWithDictionary:cacheDic];
    [self.player setCacheConfig:config];
}

/**
 底部按钮点击回调
 
 @param view settingAndConfigView
 @param index 0:媒体信息,1:刷新配置,2:cache刷新配置
 */
- (void)settingAndConfigView:(CicadaSettingAndConfigView *)view bottonButtonClickIndex:(NSInteger)index {
    NSLog(@"%ld",(long)index);
    switch (index) {
        case 0: {
            NSMutableString *infoString = [NSMutableString string];
            CicadaTrackInfo *videoTrack = [self.player getCurrentTrack:CICADA_TRACK_VIDEO];
            CicadaTrackInfo *audioTrack = [self.player getCurrentTrack:CICADA_TRACK_AUDIO];
            CicadaTrackInfo *subtitleTrack = [self.player getCurrentTrack:CICADA_TRACK_SUBTITLE];
            if (videoTrack > 0) {
                [infoString appendString:NSLocalizedString(@"清晰度:" , nil)];
                [infoString appendString:[NSString stringWithFormat:@"%d",videoTrack.trackBitrate]];
                [infoString appendString:@"; "];
            }
            if (audioTrack) {
                [infoString appendString:NSLocalizedString(@"音轨:" , nil)];
                [infoString appendString:audioTrack.description];
                [infoString appendString:@"; "];
            }
            if (subtitleTrack) {
                [infoString appendString:NSLocalizedString(@"字幕:" , nil)];
                [infoString appendString:subtitleTrack.description];
                [infoString appendString:@"; "];
            }
            if (infoString.length == 0) {
                [CicadaTool hudWithText:NSLocalizedString(@"媒体信息暂缺" , nil) view:self.view];
            }else {
                [CicadaTool hudWithText:infoString.copy view:self.view];
            }
        }
            break;
        case 1: {
            [self setConfig];
            [CicadaTool hudWithText:NSLocalizedString(@"使用成功" , nil) view:self.view];
        }
            break;
        case 2: {
            [self setCacheConfig];
            [CicadaTool hudWithText:NSLocalizedString(@"使用成功" , nil) view:self.view];
        }
            break;
        default:
            break;
    }
}

/**
 tableview点击回调
 
 @param view settingAndConfigView
 @param info 选择的track
 */
- (void)settingAndConfigView:(CicadaSettingAndConfigView *)view tableViewDidSelectTrack:(CicadaTrackInfo *)info {
    [self.player selectTrack:info.trackIndex];
}

/**
tableview点击外挂字幕回调

@param view settingAndConfigView
@param index 选择的index
@param key 选择的键
*/
- (void)settingAndConfigView:(CicadaSettingAndConfigView *)view tableViewSelectSubtitle:(int)index subtitleKey:(NSString *)key {
    if (self.extSubtitleTrackIndex != index) {
        [self.player selectExtSubtitle:self.extSubtitleTrackIndex enable:NO];
        [self.player selectExtSubtitle:index enable:YES];
        self.extSubtitleTrackIndex = index;
        [CicadaTool hudWithText:[NSString stringWithFormat:@"%@%@",NSLocalizedString(@"打开外挂字幕" , nil),key] view:self.view];
    }else {
        [self.player selectExtSubtitle:self.extSubtitleTrackIndex enable:NO];
        self.extSubtitleTrackIndex = -999;
        [CicadaTool hudWithText:[NSString stringWithFormat:@"%@%@",NSLocalizedString(@"关闭外挂字幕" , nil),key] view:self.view];
    }
}

#pragma mark CicadaDelegate

/**
 @brief 错误代理回调
 @param player 播放器player指针
 @param errorModel 播放器错误描述，参考CicadaErrorModel
 */
- (void)onError:(CicadaPlayer*)player errorModel:(CicadaErrorModel *)errorModel {
    [CicadaTool showAlert:[errorModel errorString] sender:self];
    [self.CicadaView hiddenLoadingView];
    [self.player stop];
    self.CicadaView.bufferPosition = 0;
    self.CicadaView.currentPosition = 0;
    self.CicadaView.allPosition = 0;
    [self.settingAndConfigView resetTableViewData];
}

/**
 @brief 播放器事件回调
 @param player 播放器player指针
 @param eventType 播放器事件类型，@see CicadaEventType
 */
-(void)onPlayerEvent:(CicadaPlayer*)player eventType:(CicadaEventType)eventType {
    switch (eventType) {
        case CicadaEventPrepareDone: {
            if (self.player.duration == 0) {
                self.CicadaView.hiddenSlider = YES;
            }else {
                self.CicadaView.hiddenSlider = NO;
                self.CicadaView.allPosition = self.player.duration;
            }
            CicadaTrackInfo *videoInfo = [self.player getCurrentTrack:CICADA_TRACK_VIDEO];
            NSString *bitrate = [NSString stringWithFormat:@"%d", videoInfo.trackBitrate];
            [self.settingAndConfigView setCurrentVideo:bitrate];
            [CicadaTool hudWithText:NSLocalizedString(@"准备完成" , nil) view:self.view];
        }
            break;
        case CicadaEventAutoPlayStart:
            break;
        case CicadaEventFirstRenderedStart:
            [CicadaTool hudWithText:NSLocalizedString(@"首帧显示" , nil) view:self.view];
            break;
        case CicadaEventCompletion:
            [CicadaTool hudWithText:NSLocalizedString(@"播放完成" , nil) view:self.view];
            break;
        case CicadaEventLoadingStart: {
            [self.CicadaView showLoadingView];
            [CicadaTool hudWithText:NSLocalizedString(@"缓冲开始" , nil) view:self.view];
        }
            break;
        case CicadaEventLoadingEnd: {
            [self.CicadaView hiddenLoadingView];
            [CicadaTool hudWithText:NSLocalizedString(@"缓冲完成" , nil) view:self.view];
        }
            break;
        case CicadaEventSeekEnd:
            [CicadaTool hudWithText:NSLocalizedString(@"跳转完成" , nil) view:self.view];
            break;
        case CicadaEventLoopingStart:
            [CicadaTool hudWithText:NSLocalizedString(@"循环播放开始" , nil) view:self.view];
            break;
        default:
            break;
    }
}

/**
 @brief 播放器事件回调
 @param player 播放器player指针
 @param eventWithString 播放器事件类型
 @param description 播放器事件说明
 @see CicadaEventType
 */
-(void)onPlayerEvent:(CicadaPlayer*)player eventWithString:(CicadaEventWithString)eventWithString description:(NSString *)description {
    if (eventWithString == CICADA_EVENT_SWITCH_TO_SOFTWARE_DECODER) {
        [self.settingAndConfigView setIshardwareDecoder:NO];
    }else if (eventWithString == CICADA_EVENT_PLAYER_NETWORK_RETRY) {
        NSLog(@"network Retry");
                
        if (self.retryCount > 0) {
            if ((self.currentNetworkStatus == AFNetworkReachabilityStatusReachableViaWiFi) || (self.currentNetworkStatus == AFNetworkReachabilityStatusReachableViaWWAN && self.wanWillRetry)) {
                [self.player reload];
                self.retryCount --;
            }
        }else {
            [CicadaTool hudWithText:NSLocalizedString(@"重连失败" , nil) view:self.view];
        }
    }else if (eventWithString == CICADA_EVENT_PLAYER_NETWORK_RETRY_SUCCESS) {
        self.retryCount = 3;
    } else if (eventWithString == CICADA_EVENT_PLAYER_DIRECT_COMPONENT_MSG) {
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:[description dataUsingEncoding:NSUTF8StringEncoding]
                                                            options:0
                                                              error:nil];
        NSString *value = dic[@"content"];
        if ([value isEqualToString:@"hello"]) {
            NSMutableDictionary *mutableDic = [dic mutableCopy];
            mutableDic[@"content"] = @"hi";
            NSData *data = [NSJSONSerialization dataWithJSONObject:mutableDic options:0 error:nil];
            [self.player invokeComponent:[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]];
        }
    }
    [CicadaTool hudWithText:description view:self.view];
}

/**
 @brief 视频当前播放位置回调
 @param player 播放器player指针
 @param position 视频当前播放位置
 */
- (void)onCurrentPositionUpdate:(CicadaPlayer*)player position:(int64_t)position {
    self.CicadaView.currentPosition = position;
}

/**
 @brief 视频缓存位置回调
 @param player 播放器player指针
 @param position 视频当前缓存位置
 */
- (void)onBufferedPositionUpdate:(CicadaPlayer*)player position:(int64_t)position {
    self.CicadaView.bufferPosition = position;
}

/**
 @brief 获取track信息回调
 @param player 播放器player指针
 @param info track流信息数组 参考CicadaTrackInfo
 */
- (void)onTrackReady:(CicadaPlayer*)player info:(NSArray<CicadaTrackInfo*>*)info {
    NSMutableArray * tracksArray = [NSMutableArray array];
    NSMutableArray * videoTracksArray = [NSMutableArray array];
    NSMutableArray * audioTracksArray = [NSMutableArray array];
    NSMutableArray * subtitleTracksArray = [NSMutableArray array];
    
    for (int i=0; i<info.count; i++) {
        CicadaTrackInfo* track = [info objectAtIndex:i];
        switch (track.trackType) {
            case CICADA_TRACK_VIDEO: {
                [videoTracksArray addObject:track];
            }
                break;
            case CICADA_TRACK_AUDIO: {
                [audioTracksArray addObject:track];
            }
                break;
            case CICADA_TRACK_SUBTITLE: {
                [subtitleTracksArray addObject:track];
            }
                break;
            default:
                break;
        }
    }
    if (videoTracksArray.count > 0) {
        CicadaTrackInfo *autoInfo = [[CicadaTrackInfo alloc]init];
        autoInfo.trackIndex = -1;
        autoInfo.description = @"AUTO";
        [videoTracksArray insertObject:autoInfo atIndex:0];
    }
    [tracksArray addObject:videoTracksArray];
    [tracksArray addObject:audioTracksArray];
    [tracksArray addObject:subtitleTracksArray];
    [self.settingAndConfigView setDataAndReloadWithArray:tracksArray];
    
    NSMutableArray *selectedArray = [NSMutableArray array];
    for (NSInteger i = 0; i<4; i++) {
        CicadaTrackInfo *eveinfo = [player getCurrentTrack:i];
        if (eveinfo) {
            [selectedArray addObject:[CicadaTool stringFromInt:eveinfo.trackIndex]];
        }
    }
    [self.settingAndConfigView setSelectedDataAndReloadWithArray:selectedArray];
}

- (void)onSubtitleExtAdded:(CicadaPlayer*)player trackIndex:(int)trackIndex URL:(NSString *)URL {
    NSLog(@"onSubtitleExtAdded: %@", URL);
    NSString *URLkey = @"";
    for (NSString *key in self.subtitleDictionary.allKeys) {
        if ([self.subtitleDictionary[key] isEqualToString:URL]) {
            URLkey = key;
            break;
        }
    }
    [CicadaTool hudWithText:[NSString stringWithFormat:@"%@%@%@",NSLocalizedString(@"外挂字幕" , nil),URLkey,NSLocalizedString(@"添加成功" , nil)] view:self.view];
    [self.settingAndConfigView.subtitleIndexDictionary setObject:[NSString stringWithFormat:@"%d",trackIndex] forKey:URLkey];
    [self.settingAndConfigView reloadTableView];
}

- (void)onSubtitleShow:(CicadaPlayer*)player trackIndex:(int)trackIndex subtitleID:(long)subtitleID subtitle:(NSString *)subtitle {
    [self.CicadaView setSubtitleAndShow:[CicadaTool filterHTML:subtitle]];
}

- (void)onSubtitleHide:(CicadaPlayer*)player trackIndex:(int)trackIndex subtitleID:(long)subtitleID {
    self.CicadaView.subTitleLabel.hidden = YES;
}

/**
 @brief 获取截图回调
 @param player 播放器player指针
 @param image 图像
 */
- (void)onCaptureScreen:(CicadaPlayer *)player image:(UIImage *)image {
    [CicadaShowImageView showWithImage:image inView:self.view];
}

/**
 @brief track切换完成回调
 @param player 播放器player指针
 @param info 切换后的信息 参考CicadaTrackInfo
 */
- (void)onTrackChanged:(CicadaPlayer*)player info:(CicadaTrackInfo*)info {
    NSString *description = nil;
    switch (info.trackType) {
        case CICADA_TRACK_VIDEO:
            description = [NSString stringWithFormat:@"%d", info.trackBitrate];
            break;
        case CICADA_TRACK_AUDIO:
            description = (nil != info.description)? info.description : info.audioLanguage;
            break;
        case CICADA_TRACK_SUBTITLE:
            description = (nil != info.description)? info.description : info.subtitleLanguage;
            break;
        default:
            break;
    }
    if (info.trackType == CICADA_TRACK_VIDEO) {
        [self.settingAndConfigView setCurrentVideo:description];
    }
    NSString *hudText = [description stringByAppendingString:NSLocalizedString(@"切换成功" , nil)];
    [CicadaTool hudWithText:hudText view:self.view];
}

/**
 @brief 获取缩略图成功回调
 @param positionMs 指定的缩略图位置
 @param fromPos 此缩略图的开始位置
 @param toPos 此缩略图的结束位置
 @param image 缩图略图像指针,对于mac是NSImage，iOS平台是UIImage指针
 */
- (void)onGetThumbnailSuc:(int64_t)positionMs fromPos:(int64_t)fromPos toPos:(int64_t)toPos image:(id)image {
    [self.CicadaView showThumbnailViewWithImage:(UIImage *)image];
}

/**
 @brief 获取缩略图失败回调
 @param positionMs 指定的缩略图位置
 */
- (void)onGetThumbnailFailed:(int64_t)positionMs {
    NSLog(@"获取缩略图失败");
}

/**
 @brief 视频缓冲进度回调
 @param player 播放器player指针
 @param progress 缓存进度0-100
 */
- (void)onLoadingProgress:(CicadaPlayer*)player progress:(float)progress {
    [self.CicadaView setLoadingViewProgress:(int)progress];
}

- (void)onVideoRendered:(CicadaPlayer *)player timeMs:(int64_t)timeMs pts:(int64_t)pts
{
    //   NSLog(@"onVideoRendered pts is %lld\n",pts);
}

- (void)onAudioRendered:(CicadaPlayer *)player timeMs:(int64_t)timeMs pts:(int64_t)pts
{
    //  NSLog(@"onAudioRendered pts is %lld\n",pts);
}

- (BOOL)setActive:(BOOL)active error:(NSError **)outError
{
    [[UIApplication sharedApplication] beginReceivingRemoteControlEvents];
    return [[AVAudioSession sharedInstance] setActive:active error:outError];
}

- (BOOL)setCategory:(NSString *)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError **)outError
{
//    self.enableMix = YES;
    if (self.enableMix) {
        options = AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDuckOthers;
    }
    return [[AVAudioSession sharedInstance] setCategory:category withOptions:options error:outError];
}

- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode routeSharingPolicy:(AVAudioSessionRouteSharingPolicy)policy options:(AVAudioSessionCategoryOptions)options error:(NSError **)outError
{
    if (self.enableMix) {
        return YES;
    }

    if (@available(iOS 11.0, tvOS 11.0, *)) {
        return [[AVAudioSession sharedInstance] setCategory:category mode:mode routeSharingPolicy:policy options:options error:outError];
    }
    return NO;
}

- (BOOL)onVideoPixelBuffer:(CVPixelBufferRef)pixelBuffer pts:(int64_t)pts
{
//    NSLog(@"receive HW frame:%p pts:%lld", pixelBuffer, pts);
    [self getVideoBuffer:pixelBuffer];
    return NO;
}

- (BOOL)onVideoRawBuffer:(uint8_t **)buffer lineSize:(int32_t *)lineSize pts:(int64_t)pts width:(int32_t)width height:(int32_t)height
{
//    NSLog(@"receive SW Video frame:%p pts:%lld line0:%d line1:%d line2:%d width:%d, height:%d", buffer, pts, lineSize[0], lineSize[1], lineSize[2], width, height);
    return NO;
}
- (BOOL)onAudioData:(uint8_t **)audioData lineSize:(int32_t *)lineSize pts:(int64_t)pts
{
//    NSLog(@"receive SW Audio frame:%p pts:%lld line0:%d line1:%d line2:%d", audioData, pts, lineSize[0], lineSize[1], lineSize[2]);
    [self getAudioSampleBuffer:[self createAudioSample:audioData frames:lineSize[0]]];
    return NO;
}



- (CMSampleBufferRef)createAudioSample:(void *)audioData frames:(UInt32)len

{
    int channels = 1;//2;
    
    AudioBufferList audioBufferList;
    audioBufferList.mNumberBuffers = 1;
    audioBufferList.mBuffers[0].mNumberChannels=channels;
    audioBufferList.mBuffers[0].mDataByteSize=len;
    audioBufferList.mBuffers[0].mData = audioData;
    
    AudioStreamBasicDescription asbd = [self getAudioFormat];
    
    CMSampleBufferRef buff = NULL;
    
    static CMFormatDescriptionRef format = NULL;
    
    CMTime time = CMTimeMake(len/2 , 48000);
    
    CMSampleTimingInfo timing = {CMTimeMake(1,48000), time, kCMTimeInvalid };
    
    OSStatus error = 0;
    
    if(format == NULL)
        
        error = CMAudioFormatDescriptionCreate(kCFAllocatorDefault, &asbd, 0, NULL, 0, NULL, NULL, &format);
    
    error = CMSampleBufferCreate(kCFAllocatorDefault, NULL, false, NULL, NULL, format, len/(2*channels), 1, &timing, 0, NULL, &buff);
    
    if ( error ) {
        NSLog(@"CMSampleBufferCreate returned error: %ld", (long)error);
        return NULL;
    }
    
    error = CMSampleBufferSetDataBufferFromAudioBufferList(buff, kCFAllocatorDefault, kCFAllocatorDefault, 0, &audioBufferList);
    
    if( error )
    {
        NSLog(@"CMSampleBufferSetDataBufferFromAudioBufferList returned error: %ld", (long)error);
        return NULL;
    }
    
    return buff;
}

-(AudioStreamBasicDescription) getAudioFormat{
    
    AudioStreamBasicDescription format;
    
    format.mSampleRate = 48000;
    
    format.mFormatID = kAudioFormatLinearPCM;
    
    format.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger;
    
    format.mBytesPerPacket = 2;//*2;
    
    format.mFramesPerPacket = 1;
    
    format.mBytesPerFrame = 2;//*2;
    
    format.mChannelsPerFrame = 1;//2;
    
    format.mBitsPerChannel = 16;
    
    format.mReserved = 0;
    
    return format;
}
- (void)recordClick:(UIButton *)sender {
    if (!sender.selected) {
        [self startRecorder];
    } else {
        [self stopRecorder];
    }
    sender.selected = !sender.selected;
}
//-(void)setUpWriter{
//    if (self.recordingURL == nil)
//    {
//        return;
//    }
//    self.assetWriter = [AVAssetWriter assetWriterWithURL:self.recordingURL fileType:AVFileTypeMPEG4 error:nil];
//    float bitsPerPixel;
//    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions( _videoTrackSourceFormatDescription );
//    int numPixels = dimensions.width * dimensions.height;
//    int bitsPerSecond;
//
//    NSLog( @"No video settings provided, using default settings" );
//
//    // Assume that lower-than-SD resolutions are intended for streaming, and use a lower bitrate
//    if ( numPixels < ( 640 * 480 ) ) {
//        bitsPerPixel = 4.05; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetMedium or Low.
//    }
//    else {
//        bitsPerPixel = 10.1; // This bitrate approximately matches the quality produced by AVCaptureSessionPresetHigh.
//    }
//
//    bitsPerSecond = numPixels * bitsPerPixel;
//    NSDictionary *compressionProperties = @{ AVVideoAverageBitRateKey : @(bitsPerSecond),
//                                             AVVideoExpectedSourceFrameRateKey : @(30),
//                                             AVVideoMaxKeyFrameIntervalKey : @(30) };
//
//    _videoCompressionSettings = @{ AVVideoCodecKey : AVVideoCodecH264,
//                       AVVideoWidthKey : @(dimensions.width),
//                       AVVideoHeightKey : @(dimensions.height),
//                       AVVideoCompressionPropertiesKey : compressionProperties };
//
//    if ( [_assetWriter canApplyOutputSettings:_videoCompressionSettings forMediaType:AVMediaTypeVideo] )
//    {
//        _assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:_videoCompressionSettings];
//        _assetWriterVideoInput.expectsMediaDataInRealTime = YES;
////        _assetWriterVideoInput.transform = transform;
//
//        if ( [_assetWriter canAddInput:_assetWriterVideoInput] )
//        {
//            [_assetWriter addInput:_assetWriterVideoInput];
//            NSLog(@"添加视频输入成功");
//        } else {
//            NSLog(@"添加视频输入失败");
//        }
//    }
//
//    _audioCompressionSettings = @{ AVFormatIDKey : @(kAudioFormatMPEG4AAC) };
//    if ( [_assetWriter canApplyOutputSettings:_audioCompressionSettings forMediaType:AVMediaTypeAudio] )
//    {
//        _assetWriterAudioInput = [[AVAssetWriterInput alloc] initWithMediaType:AVMediaTypeAudio outputSettings:_audioCompressionSettings sourceFormatHint:_audioTrackSourceFormatDescription];
//        _assetWriterAudioInput.expectsMediaDataInRealTime = YES;
//
//        if ( [_assetWriter canAddInput:_assetWriterAudioInput] )
//        {
//            [_assetWriter addInput:_assetWriterAudioInput];
//            NSLog(@"添加音频输入成功");
//        }
//        else
//        {
//            NSLog(@"添加音频输入失败");
//        }
//    }
//
//}
/**
 *  开始写入数据
 */
- (void)appendSampleBuffer:(CMSampleBufferRef)sampleBuffer ofMediaType:(NSString *)mediaType
{
    BOOL isVideo = YES;
    @synchronized(self) {
        if (!self.isCapturing || self.isPaused) {
            return;
        }
        if (mediaType != AVMediaTypeVideo) {
            isVideo = NO;
        }
        //初始化编码器，当有音频和视频参数时创建编码器
        if (self.recordEncoder == nil) {
            self.recordEncoder = [[WCLRecordEncoder alloc] initPath:self.recordingURL.path];
            if (isVideo) {
                [self.recordEncoder initVideoInputHeight:_cy width:_cx];
            } else {
                CMFormatDescriptionRef fmt = CMSampleBufferGetFormatDescription(sampleBuffer);
                [self.recordEncoder initAudioInputChannels:_channels samples:_samplerate];
            }
        }
        
        //判断是否中断录制过
        if (self.discont) {
            if (isVideo) {
                return;
            }
            self.discont = NO;
            // 计算暂停的时间
            CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
            CMTime last = isVideo ? _lastVideo : _lastAudio;
            if (last.flags & kCMTimeFlags_Valid) {
                if (_timeOffset.flags & kCMTimeFlags_Valid) {
                    pts = CMTimeSubtract(pts, _timeOffset);
                }
                CMTime offset = CMTimeSubtract(pts, last);
                if (_timeOffset.value == 0) {
                    _timeOffset = offset;
                }else {
                    _timeOffset = CMTimeAdd(_timeOffset, offset);
                }
            }
            _lastVideo.flags = 0;
            _lastAudio.flags = 0;
        }
        // 增加sampleBuffer的引用计时,这样我们可以释放这个或修改这个数据，防止在修改时被释放
        CFRetain(sampleBuffer);
        if (_timeOffset.value > 0) {
            CFRelease(sampleBuffer);
            //根据得到的timeOffset调整
            sampleBuffer = [self adjustTime:sampleBuffer by:_timeOffset];
        }
        // 记录暂停上一次录制的时间
        CMTime pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
        CMTime dur = CMSampleBufferGetDuration(sampleBuffer);
        if (dur.value > 0) {
            pts = CMTimeAdd(pts, dur);
        }
        if (isVideo) {
            _lastVideo = pts;
        }else {
            _lastAudio = pts;
        }
    }
    CMTime dur = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if (self.startTime.value == 0) {
        self.startTime = dur;
    }
    CMTime sub = CMTimeSubtract(dur, self.startTime);
    self.currentRecordTime = CMTimeGetSeconds(sub);
    // 进行数据编码
    [self.recordEncoder encodeFrame:sampleBuffer isVideo:isVideo];
    CFRelease(sampleBuffer);
}
//设置音频格式
- (void)setAudioFormat:(CMFormatDescriptionRef)fmt {
    const AudioStreamBasicDescription *asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt);
    _samplerate = asbd->mSampleRate;
    _channels = asbd->mChannelsPerFrame;
    NSLog(@"音频采样率%.2f = ", _samplerate);
    NSLog(@"音频通道%d = ", _channels);
    
}

//调整媒体数据的时间
- (CMSampleBufferRef)adjustTime:(CMSampleBufferRef)sample by:(CMTime)offset {
    CMItemCount count;
    CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
    CMSampleTimingInfo* pInfo = malloc(sizeof(CMSampleTimingInfo) * count);
    CMSampleBufferGetSampleTimingInfoArray(sample, count, pInfo, &count);
    for (CMItemCount i = 0; i < count; i++) {
        pInfo[i].decodeTimeStamp = CMTimeSubtract(pInfo[i].decodeTimeStamp, offset);
        pInfo[i].presentationTimeStamp = CMTimeSubtract(pInfo[i].presentationTimeStamp, offset);
    }
    CMSampleBufferRef sout;
    CMSampleBufferCreateCopyWithNewTiming(nil, sample, count, pInfo, &sout);
    free(pInfo);
    return sout;
}
//开始录视频
- (void)startRecorder
{
}
//停止录视频
- (void)stopRecorder
{
    
}
// 将CVPixelBufferRef转换成CMSampleBufferRef

-(CMSampleBufferRef)pixelBufferToSampleBuffer:(CVPixelBufferRef)pixelBuffer

{

    

    CMSampleBufferRef sampleBuffer;

    CMTime frameTime = CMTimeMakeWithSeconds([[NSDate date] timeIntervalSince1970], 1000000000);

    CMSampleTimingInfo timing = {frameTime, frameTime, kCMTimeInvalid};

    CMVideoFormatDescriptionRef videoInfo = NULL;

    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);

    

    OSStatus status = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault, pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);

    if (status != noErr) {

        NSLog(@"Failed to create sample buffer with error %zd.", status);

    }

    CVPixelBufferRelease(pixelBuffer);

    if(videoInfo)

        CFRelease(videoInfo);

    

    return sampleBuffer;

}
//录视频，处理拿到的视频帧
- (void)getVideoBuffer:(CVPixelBufferRef)pixelBufferRef
{
    
    CMFormatDescriptionRef videoInfo = NULL;
    CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBufferRef, &videoInfo);
    CMVideoDimensions dimensions = CMVideoFormatDescriptionGetDimensions( videoInfo );
    _cx = dimensions.width;
    _cy = dimensions.height;
    dispatch_async(self.captureQueue, ^{
        CMSampleBufferRef sampleBuffer = [self pixelBufferToSampleBuffer:pixelBufferRef];
        [self appendSampleBuffer:sampleBuffer ofMediaType:AVMediaTypeVideo];
    });
    CFRelease(videoInfo);
}

//录视频，处理拿到的音频帧
- (void)getAudioSampleBuffer:(CMSampleBufferRef)sampleBufferRef
{
    CMFormatDescriptionRef formatDescription = CMSampleBufferGetFormatDescription(sampleBufferRef);
    [self setAudioFormat:formatDescription];
    dispatch_async(self.captureQueue, ^{
        [self appendSampleBuffer:sampleBufferRef ofMediaType:AVMediaTypeAudio];
    });
}



- (NSString *)createVideoFilePath
{
    // 创建视频文件的存储路径
    NSString *filePath = [self createVideoFolderPath];
    if (filePath == nil)
    {
        return nil;
    }
    
    NSString *videoType = @".mp4";
    NSString *videoDestDateString = [self createFileNamePrefix];
    NSString *videoFileName = [videoDestDateString stringByAppendingString:videoType];
    
    NSUInteger idx = 1;
    /*We only allow 10000 same file name*/
    NSString *finalPath = [NSString stringWithFormat:@"%@/%@", filePath, videoFileName];
    
    while (idx % 10000 && [[NSFileManager defaultManager] fileExistsAtPath:finalPath])
    {
        finalPath = [NSString stringWithFormat:@"%@/%@_(%lu)%@", filePath, videoDestDateString, (unsigned long)idx++, videoType];
    }
    
    return finalPath;
}

- (NSString *)createVideoFolderPath
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSString *homePath = NSHomeDirectory();
    
    NSString *tmpFilePath;
    
    if (homePath.length > 0)
    {
        NSString *documentPath = [homePath stringByAppendingString:@"/Documents"];
        if ([fileManager fileExistsAtPath:documentPath isDirectory:NULL] == YES)
        {
            BOOL success = NO;
            
            NSArray *paths = [fileManager contentsOfDirectoryAtPath:documentPath error:nil];
            
            //offline file folder
            tmpFilePath = [documentPath stringByAppendingString:[NSString stringWithFormat:@"/%@", VIDEO_FILEPATH]];
            if ([paths containsObject:VIDEO_FILEPATH] == NO)
            {
                success = [fileManager createDirectoryAtPath:tmpFilePath withIntermediateDirectories:YES attributes:nil error:nil];
                if (!success)
                {
                    tmpFilePath = nil;
                }
            }
            return tmpFilePath;
        }
    }
    
    return false;
}

/**
 *  创建文件名
 */
- (NSString *)createFileNamePrefix
{
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
    
    NSString *destDateString = [dateFormatter stringFromDate:[NSDate date]];
    destDateString = [destDateString stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    destDateString = [destDateString stringByReplacingOccurrencesOfString:@"+" withString:@"-"];
    destDateString = [destDateString stringByReplacingOccurrencesOfString:@":" withString:@"-"];
    
    return destDateString;
}

////录制的队列
- (dispatch_queue_t)captureQueue {
    if (_captureQueue == nil) {
        _captureQueue = dispatch_queue_create("cn.qiuyouqun.im.wclrecordengine.capture", DISPATCH_QUEUE_SERIAL);
    }
    return _captureQueue;
}
#pragma mark - 公开的方法
//启动录制功能
- (void)startUp{
    self.startTime = CMTimeMake(0, 0);
    self.isCapturing = NO;
    self.isPaused = NO;
    self.discont = NO;
}

//关闭录制功能
- (void)shutdown {
    _startTime = CMTimeMake(0, 0);
    [_recordEncoder finishWithCompletionHandler:^{
//        NSLog(@"录制完成");
    }];
}

//开始录制
- (void) startCapture {
    @synchronized(self) {
        if (!self.isCapturing) {
//            NSLog(@"开始录制");
            self.recordEncoder = nil;
            self.isPaused = NO;
            self.discont = NO;
            _timeOffset = CMTimeMake(0, 0);
            self.isCapturing = YES;
        }
    }
}
//暂停录制
- (void) pauseCapture {
    @synchronized(self) {
        if (self.isCapturing) {
//            NSLog(@"暂停录制");
            self.isPaused = YES;
            self.discont = YES;
        }
    }
}
//继续录制
- (void) resumeCapture {
    @synchronized(self) {
        if (self.isPaused) {
//            NSLog(@"继续录制");
            self.isPaused = NO;
        }
    }
}
//停止录制
- (void) stopCaptureHandler:(void (^)(UIImage *movieImage))handler {
    @synchronized(self) {
        if (self.isCapturing) {
            NSString* path = self.recordEncoder.path;
            NSURL* url = [NSURL fileURLWithPath:path];
            self.isCapturing = NO;
            dispatch_async(_captureQueue, ^{
                [self.recordEncoder finishWithCompletionHandler:^{
                    self.isCapturing = NO;
                    self.recordEncoder = nil;
                    self.startTime = CMTimeMake(0, 0);
                    self.currentRecordTime = 0;
                    [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                        [PHAssetChangeRequest creationRequestForAssetFromVideoAtFileURL:url];
                    } completionHandler:^(BOOL success, NSError * _Nullable error) {
                        NSLog(@"保存成功");
                    }];
                }];
            });
        }
    }
}
@end
