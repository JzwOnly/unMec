//
//  JZVLCPlayerManager.h
//  ijkplayerRTSP
//
//  Created by admin on 2021/7/28.
//  Copyright © 2021 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#if __has_include(<ZFPlayer/ZFPlayerMediaPlayback.h>)
#import <ZFPlayer/ZFPlayerMediaPlayback.h>
#else
#import "ZFPlayerMediaPlayback.h"
#endif

#if __has_include(<MobileVLCKit/MobileVLCKit.h>)
#import <MobileVLCKit/MobileVLCKit.h>
#endif
@interface JZVLCPlayerManager : NSObject <ZFPlayerMediaPlayback>
@property (nonatomic, strong, readonly) VLCMediaPlayer *player;

//@property (nonatomic, strong, readonly) IJKFFOptions *options;

@property (nonatomic, assign) NSTimeInterval timeRefreshInterval;

@property (nonatomic, copy, nullable) void(^recordStarted)(void);
@property (nonatomic, copy, nullable) void(^recordStoped)(NSString * path);
@property (nonatomic, copy, nullable) void(^snapshotCallback)(UIImage * image);

@end

