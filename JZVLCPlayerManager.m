//
//  JZVLCPlayerManager.m
//  ijkplayerRTSP
//
//  Created by admin on 2021/7/28.
//  Copyright © 2021 admin. All rights reserved.
//

#import "JZVLCPlayerManager.h"
#if __has_include(<ZFPlayer/ZFPlayer.h>)
#import <ZFPlayer/ZFPlayer.h>
#import <ZFPlayer/ZFPlayerConst.h>
#else
#import "ZFPlayer.h"
#import "ZFPlayerConst.h"
#endif
#if __has_include(<MobileVLCKit/MobileVLCKit.h>)

@interface JZVLCPlayerManager()
@property (nonatomic, strong) VLCMediaPlayer *player;
//@property (nonatomic, strong) IJKFFOptions *options;
@property (nonatomic, assign) CGFloat lastVolume;
@property (nonatomic, strong) NSTimer *timer;
@property (nonatomic, assign) BOOL isReadyToPlay;
@end
@implementation JZVLCPlayerManager
@synthesize view                           = _view;
@synthesize currentTime                    = _currentTime;
@synthesize totalTime                      = _totalTime;
@synthesize playerPlayTimeChanged          = _playerPlayTimeChanged;
@synthesize playerBufferTimeChanged        = _playerBufferTimeChanged;
@synthesize playerDidToEnd                 = _playerDidToEnd;
@synthesize bufferTime                     = _bufferTime;
@synthesize playState                      = _playState;
@synthesize loadState                      = _loadState;
@synthesize assetURL                       = _assetURL;
@synthesize playerPrepareToPlay            = _playerPrepareToPlay;
@synthesize playerReadyToPlay              = _playerReadyToPlay;
@synthesize playerPlayStateChanged         = _playerPlayStateChanged;
@synthesize playerLoadStateChanged         = _playerLoadStateChanged;
@synthesize seekTime                       = _seekTime;
@synthesize muted                          = _muted;
@synthesize volume                         = _volume;
@synthesize presentationSize               = _presentationSize;
@synthesize isPlaying                      = _isPlaying;
@synthesize rate                           = _rate;
@synthesize isPreparedToPlay               = _isPreparedToPlay;
@synthesize shouldAutoPlay                 = _shouldAutoPlay;
@synthesize scalingMode                    = _scalingMode;
@synthesize playerPlayFailed               = _playerPlayFailed;
@synthesize presentationSizeChanged        = _presentationSizeChanged;

- (void)dealloc {
    [self stop];
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _scalingMode = ZFPlayerScalingModeAspectFit;
        _shouldAutoPlay = YES;
    }
    return self;
}

- (void)prepareToPlay {
    if (!_assetURL) return;
    _isPreparedToPlay = YES;
    [self initializePlayer];
    if (self.shouldAutoPlay) {
        [self play];
    }
    self.loadState = ZFPlayerLoadStatePrepare;
    if (self.playerPrepareToPlay) self.playerPrepareToPlay(self, self.assetURL);
}

- (void)reloadPlayer {
    [self prepareToPlay];
}

- (void)play {
    if (!_isPreparedToPlay) {
        [self prepareToPlay];
    } else {
        [self.player play];
        self.player.rate = self.rate;
        _isPlaying = YES;
        self.playState = ZFPlayerPlayStatePlaying;
    }
}

- (void)pause {
    [self.player pause];
    _isPlaying = NO;
    self.playState = ZFPlayerPlayStatePaused;
}

- (void)stop {
    [self removeMovieNotificationObservers];
    [self.player stop];
    [self.player.drawable removeFromSuperview];
    self.player = nil;
    _assetURL = nil;
    [self.timer invalidate];
    self.presentationSize = CGSizeZero;
    self.timer = nil;
    _isPlaying = NO;
    _isPreparedToPlay = NO;
    self->_currentTime = 0;
    self->_totalTime = 0;
    self->_bufferTime = 0;
    self.isReadyToPlay = NO;
    self.playState = ZFPlayerPlayStatePlayStopped;
}

- (void)replay {
    @zf_weakify(self)
    [self seekToTime:0 completionHandler:^(BOOL finished) {
        @zf_strongify(self)
        if (finished) {
            [self play];
        }
    }];
}

- (void)seekToTime:(NSTimeInterval)time completionHandler:(void (^ __nullable)(BOOL finished))completionHandler {
    if (self.player.remainingTime.intValue > 0 && self.player.isSeekable) {
        float position = (time / (float)self.player.remainingTime.intValue);
        [self.player setPosition: position];
        if (completionHandler) completionHandler(YES);
    } else {
        self.seekTime = time;
    }
}

#pragma mark - private method

- (void)initializePlayer {
    self.player = [[VLCMediaPlayer alloc] init];
    self.player.media = [VLCMedia mediaWithURL:self.assetURL];
//    self.player = [[IJKFFMoviePlayerController alloc] initWithContentURL:self.assetURL withOptions:self.options];
//    self.player.shouldAutoplay = self.shouldAutoPlay;
//    [self.player prepareToPlay];
    self.player.drawable = self.view.playerView;
//    self.view.playerView = self.player.view;
    self.scalingMode = self->_scalingMode;
//    [self addPlayerNotificationObservers];
}

- (void)addPlayerNotificationObservers {
    /// 准备播放
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(loadStateDidChange:)
//                                                 name:VLCMediaPlayerStateChanged
//                                               object:_player];
//    /// 播放完成或者用户退出
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(moviePlayBackFinish:)
//                                                 name:IJKMPMoviePlayerPlaybackDidFinishNotification
//                                               object:_player];
    /// 准备开始播放了
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(movieTimeDidChange:)
                                                 name:VLCMediaPlayerTimeChanged
                                               object:_player];
    /// 播放状态改变了
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(moviePlayBackStateDidChange:)
                                                 name:VLCMediaPlayerStateChanged
                                               object:_player];
//
//    /// 视频的尺寸变化了
//    [[NSNotificationCenter defaultCenter] addObserver:self
//                                             selector:@selector(sizeAvailableChange:)
//                                                 name:IJKMPMovieNaturalSizeAvailableNotification
//                                               object:self.player];
}
//
- (void)removeMovieNotificationObservers {
//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:VLCMediaPlayerStateChanged
//                                                  object:_player];
//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:IJKMPMoviePlayerPlaybackDidFinishNotification
//                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:VLCMediaPlayerTimeChanged
                                                  object:_player];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:VLCMediaPlayerStateChanged
                                                  object:_player];
//    [[NSNotificationCenter defaultCenter] removeObserver:self
//                                                    name:IJKMPMovieNaturalSizeAvailableNotification
//                                                  object:_player];
}

- (void)timerUpdate {
    if (self.player.time.intValue > 0 && !self.isReadyToPlay) {
        self.isReadyToPlay = YES;
        self.loadState = ZFPlayerLoadStatePlaythroughOK;
    }
    self->_currentTime = self.player.time.intValue > 0 ? self.player.time.intValue : 0;
    self->_totalTime = self.player.remainingTime.intValue;
    self->_bufferTime = 0;
    if (self.playerPlayTimeChanged) self.playerPlayTimeChanged(self, self.currentTime, self.totalTime);
    if (self.playerBufferTimeChanged) self.playerBufferTimeChanged(self, self.bufferTime);
}

#pragma - notification

// 时间改变
- (void)movieTimeDidChange:(NSNotification *)notification {
    ZFPlayerLog(@"加载状态变成了已经缓存完成，如果设置了自动播放, 会自动播放");
    // 视频开始播放的时候开启计时器
    if (!self.timer) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:self.timeRefreshInterval > 0 ? self.timeRefreshInterval : 0.1 target:self selector:@selector(timerUpdate) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.timer forMode:NSRunLoopCommonModes];
    }

    if (self.isPlaying) {
        [self play];
        self.muted = self.muted;
        if (self.seekTime > 0) {
            [self seekToTime:self.seekTime completionHandler:nil];
            self.seekTime = 0; // 滞空, 防止下次播放出错
            [self play];
        }
    }
    if (self.playerReadyToPlay) self.playerReadyToPlay(self, self.assetURL);
}



#pragma mark - 加载状态改变
// 播放状态改变
- (void)moviePlayBackStateDidChange:(NSNotification *)notification {
    NSLog(@"state: %@",VLCMediaPlayerStateToString(_player.state));
    switch (_player.state) {
        case VLCMediaPlayerStateStopped:
        {
            ZFPlayerLog(@"播放器的播放状态变了，现在是停止状态 %d: stoped", (int)_player.state);
            // 这里的回调也会来多次(一次播放完成, 会回调三次), 所以, 这里不设置
            self.playState = ZFPlayerPlayStatePlayStopped;
        }
        break;
        case VLCMediaPlayerStatePlaying:
        {
            ZFPlayerLog(@"播放器的播放状态变了，现在是播放状态 %d: playing", (int)_player.state);
        }
        break;
        case VLCMediaPlayerStateEnded:
        {
            ZFPlayerLog(@"playbackStateDidChange: 播放完毕: %d\n", (int)_player.state);
            self.playState = ZFPlayerPlayStatePlayStopped;
            if (self.playerDidToEnd) self.playerDidToEnd(self);
        }
        break;
        case VLCMediaPlayerStateError:
        {
            ZFPlayerLog(@"playbackStateDidChange: 播放出现错误: %d\n", (int)_player.state);
            self.playState = ZFPlayerPlayStatePlayFailed;
            if (self.playerPlayFailed) self.playerPlayFailed(self, @((int)_player.state));
        }
        break;
        case VLCMediaPlayerStatePaused:
        {
            ZFPlayerLog(@"播放器的播放状态变了，现在是暂停状态 %d: paused", (int)_player.state);
        }
        break;
        default:
        break;
    }
}

#pragma mark - getter

- (ZFPlayerView *)view {
    if (!_view) {
        _view = [[ZFPlayerView alloc] init];
    }
    return _view;
}

- (float)rate {
    return _rate == 0 ?1:_rate;
}

//- (IJKFFOptions *)options {
//    if (!_options) {
//        _options = [IJKFFOptions optionsByDefault];
//        /// 精准seek
//        [_options setPlayerOptionIntValue:1 forKey:@"enable-accurate-seek"];
//        /// 解决http播放不了
//        [_options setOptionIntValue:1 forKey:@"dns_cache_clear" ofCategory:kIJKFFOptionCategoryFormat];
//    }
//    return _options;
//}

#pragma mark - setter

- (void)setPlayState:(ZFPlayerPlaybackState)playState {
    _playState = playState;
    if (self.playerPlayStateChanged) self.playerPlayStateChanged(self, playState);
}

- (void)setLoadState:(ZFPlayerLoadState)loadState {
    _loadState = loadState;
    if (self.playerLoadStateChanged) self.playerLoadStateChanged(self, loadState);
}

- (void)setAssetURL:(NSURL *)assetURL {
    if (self.player) [self stop];
    _assetURL = assetURL;
    [self prepareToPlay];
}

- (void)setRate:(float)rate {
    _rate = rate;
    if (self.player && fabsf(_player.rate) > 0.00001f) {
        self.player.rate = rate;
    }
}

- (void)setMuted:(BOOL)muted {
    _muted = muted;
    if (muted) {
        self.lastVolume = self.player.audio.volume;
        self.player.audio.volume = 0;
    } else {
        /// Fix first called the lastVolume is 0.
        if (self.lastVolume == 0) self.lastVolume = self.player.audio.volume;
        self.player.audio.volume = self.lastVolume;
    }
}

- (void)setScalingMode:(ZFPlayerScalingMode)scalingMode {
    _scalingMode = scalingMode;
    self.view.scalingMode = scalingMode;
//    switch (scalingMode) {
//        case ZFPlayerScalingModeNone:
//            self.player.scalingMode = IJKMPMovieScalingModeNone;
//            break;
//        case ZFPlayerScalingModeAspectFit:
//            self.player.scalingMode = IJKMPMovieScalingModeAspectFit;
//            break;
//        case ZFPlayerScalingModeAspectFill:
//            self.player.scalingMode = IJKMPMovieScalingModeAspectFill;
//            break;
//        case ZFPlayerScalingModeFill:
//            self.player.scalingMode = IJKMPMovieScalingModeFill;
//            break;
//        default:
//            break;
//    }
}

- (void)setVolume:(float)volume {
    _volume = MIN(MAX(0, volume), 1);
    self.player.audio.volume = volume;
}

@end

#endif
