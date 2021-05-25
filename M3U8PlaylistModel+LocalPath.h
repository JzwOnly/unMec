//
//  M3U8PlaylistModel+_LocalPath.h
//  Demo
//
//  Created by admin on 2021/4/20.
//  Copyright © 2021 jzw. All rights reserved.
//

#import <M3U8Kit/M3U8Parser.h>

@interface M3U8PlaylistModel (LocalPath)
- (void)savePlaylistsToPath:(NSString *)path vid:(int)vid episodeNum:(int)episodeNum rewrite:(BOOL)rewrite keymap:(NSDictionary *)keymap error:(NSError **)error;
@end
