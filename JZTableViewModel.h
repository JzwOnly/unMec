//
//  JZTableViewModel.h
//  CMEPlayer
//
//  Created by admin on 2021/1/8.
//  Copyright © 2021 admin. All rights reserved.
//

#import "JZViewModel.h"
#import "EmptyModel.h"
#import <ReactiveObjC/ReactiveObjC.h>

@interface JZTableViewModel : JZViewModel
@property (nonatomic, readwrite , strong) EmptyModel * emptyModel;
/// The data source of table view. 这里不能用NSMutableArray，因为NSMutableArray不支持KVO，不能被RACObserve
@property (nonatomic, readwrite, copy) NSArray *dataSource;

/// 选中命令 eg:  didSelectRowAtIndexPath:
@property (nonatomic, readwrite, strong) RACCommand *didSelectCommand;
@end

