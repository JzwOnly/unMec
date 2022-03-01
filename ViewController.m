//
//  ViewController.m
//  BMPTest
//
//  Created by cme on 2022/3/1.
//

#import "ViewController.h"
#import <SDWebImage/SDWebImage.h>
//#define bmpUrl @"http://192.168.132.102:7001/162/001.bmp"
#define bmpUrl @"https://raw.githubusercontent.com/JzwOnly/unMec/main/001.bmp"
@interface ViewController ()
@property(nonatomic, strong)UIImageView * onlineImgV;
@property(nonatomic, strong)UIImageView * diskImgV;
@property(nonatomic, strong)UIButton * loadDiskBtn;
@property(nonatomic, strong)UIButton * loadFilePathBtn;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.onlineImgV = [[UIImageView alloc] init];
    [self.onlineImgV sd_setImageWithURL:[NSURL URLWithString:bmpUrl]];
    [self.view addSubview:self.onlineImgV];
    
    self.diskImgV = [[UIImageView alloc] init];
    [self.view addSubview:self.diskImgV];
    
    self.loadDiskBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loadDiskBtn.backgroundColor = [UIColor greenColor];
    [self.loadDiskBtn addTarget:self action:@selector(handleLoadDiskWithSDCache:) forControlEvents:UIControlEventTouchUpInside];
    [self.loadDiskBtn setTitle:@"SDMemory" forState:UIControlStateNormal];
    [self.view addSubview:self.loadDiskBtn];
    
    self.loadFilePathBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.loadFilePathBtn.backgroundColor = [UIColor greenColor];
    [self.loadFilePathBtn addTarget:self action:@selector(handleLoadDiskWithFilePath:) forControlEvents:UIControlEventTouchUpInside];
    [self.loadFilePathBtn setTitle:@"FilePath" forState:UIControlStateNormal];
    [self.view addSubview:self.loadFilePathBtn];
}
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.onlineImgV.frame = CGRectMake((CGRectGetWidth(self.view.bounds)-200)/2, 100, 200, 200);
    
    self.diskImgV.frame = CGRectMake((CGRectGetWidth(self.view.bounds)-200)/2, 400, 200, 200);
    
    self.loadDiskBtn.frame = CGRectMake((CGRectGetWidth(self.view.bounds)-260)/2, 640, 120, 60);
    
    self.loadFilePathBtn.frame = CGRectMake(CGRectGetMaxX(self.loadDiskBtn.frame)+20, 640, 120, 60);
}
- (void)handleLoadDiskWithSDCache:(UIButton *)sender{
    UIImage * image = nil;
    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:[NSURL URLWithString:bmpUrl]];
    BOOL exists = [[SDImageCache sharedImageCache] diskImageDataExistsWithKey:key];
    if (exists) {
//        image = [[SDImageCache sharedImageCache] imageFromMemoryCacheForKey:key];
//        image = [[SDImageCache sharedImageCache] imageFromCacheForKey:key];
        image = [[SDImageCache sharedImageCache] imageFromDiskCacheForKey:key];
    }
    if (image) {
        self.diskImgV.image = image;
    } else {
        NSLog(@"store image failed");
    }
}
- (void)handleLoadDiskWithFilePath:(UIButton *)sender {
    UIImage * image = nil;
    NSString *key = [[SDWebImageManager sharedManager] cacheKeyForURL:[NSURL URLWithString:bmpUrl]];
    BOOL exists = [[SDImageCache sharedImageCache] diskImageDataExistsWithKey:key];
    if (exists) {
        NSString * filePath = [[SDImageCache sharedImageCache] cachePathForKey:key];
        image = [UIImage imageWithContentsOfFile:filePath];
    }
    if (image) {
        self.diskImgV.image = image;
    } else {
        NSLog(@"store image failed");
    }
}

@end
