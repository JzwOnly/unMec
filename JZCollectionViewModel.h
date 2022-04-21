//
//  JZCollectionViewModel.h
//  iEndo
//
//  Created by cme on 2022/1/11.
//

#import "JZViewModel.h"
#import "EmptyModel.h"
@interface JZCollectionViewModel : JZViewModel
@property (nonatomic, readwrite , strong) EmptyModel * emptyModel;
/// The data source of table view. 这里不能用NSMutableArray，因为NSMutableArray不支持KVO，不能被RACObserve
@property (nonatomic, readwrite, copy) NSArray *dataSource;

/// 选中命令 eg:  didSelectRowAtIndexPath:
@property (nonatomic, readwrite, strong) RACCommand *didSelectCommand;
@end


