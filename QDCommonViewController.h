//
//  QDCommonViewController.h
//  qmuidemo
//
//  Created by QMUI Team on 15/4/13.
//  Copyright (c) 2015年 QMUI Team. All rights reserved.
//
#import "JZViewModel.h"
@interface QDCommonViewController : QMUICommonViewController
/// The `viewModel` parameter in `-initWithViewModel:` method.
@property (nonatomic, readonly, strong) JZViewModel *viewModel;

/// Returns a new view.
- (instancetype)initWithViewModel:(JZViewModel *)viewModel;
/// Binds the corresponding view model to the view.(绑定数据模型)
- (void)bindViewModel;

- (void)showToastWithTips:(QMUITips *)tips info:(NSString *)info detailText:(NSString *)detailText;
@end
