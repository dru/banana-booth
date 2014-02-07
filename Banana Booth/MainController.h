//
//  MainController.h
//  Banana Booth
//
//  Created by Andrey Melnik on 19.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface MainController : UIViewController <UIScrollViewDelegate>

@property (nonatomic, weak) IBOutlet UIButton *start_button;
@property (nonatomic, weak) IBOutlet UIScrollView *scrollview;
@property (nonatomic, weak) IBOutlet UIButton *right_button;
@property (nonatomic, weak) IBOutlet UIButton *left_button;
@property (nonatomic, weak) IBOutlet UIView *footer;
@property (nonatomic, weak) IBOutlet UIImageView *titleImage;
@property (nonatomic, assign) NSUInteger page;

- (IBAction)right_touch:(id)sender;
- (IBAction)left_touch:(id)sender;

@end
