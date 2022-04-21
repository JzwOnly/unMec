//
//  JZViewModel.h
//  MVVM+RAC+QMUIKit
//
//  Created by admin on 2020/12/18.
//  Copyright © 2020 admin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <ReactiveObjC/ReactiveObjC.h>

@interface JZViewModel : NSObject
/// The `params` parameter in `-initWithParams:` method.
/// The `params` Key's `kBaseViewModelParamsKey`
@property (nonatomic, readonly, copy) NSDictionary *params;
/// navItem.title
@property (nonatomic, readwrite, copy) NSString *title;
/// 返回按钮的title，default is nil 。
/// 如果设置了该值，那么当Push到一个新的控制器,则导航栏左侧返回按钮的title为backTitle
@property (nonatomic, readwrite, copy) NSString *backTitle;

/// A RACSubject object, which representing all errors occurred in view model.
@property (nonatomic, readonly, strong) RACSubject *errors;
/// will disappear signal
@property (nonatomic, strong, readonly) RACSubject *willDisappearSignal;
@property(nonatomic, strong)RACSubject * showTipSubject;

- (void)initialize;
- (instancetype)initWithParams:(NSDictionary *)params;
- (BOOL)changeParamsValue:(id)value forKey:(NSString *)key;
@end

