//
//  EmptyModel.h
//  iEndo
//
//  Created by cme on 2021/11/2.
//

#import <Foundation/Foundation.h>

@interface EmptyModel: NSObject
@property(nonatomic, assign)BOOL showLoading;
@property(nonatomic, strong)UIImage *image;
@property(nonatomic, strong)NSString *text;
@property(nonatomic, strong)NSString *detailText;
@property(nonatomic, strong)NSString *buttonTitle;
@property(nonatomic, strong)UIImage *buttonImage;
@property(nonatomic, assign)SEL buttonAction;
+ (instancetype)emptyWithShowLoading:(BOOL)showLoading image:(UIImage *)image text:(NSString *)text detailText:(NSString *)detailText buttonTitle:(NSString *)buttonTitle buttonImage:(UIImage *)buttonImage buttonAction:(SEL)buttonAction;
@end
