//
//  MainController.m
//  Banana Booth
//
//  Created by Andrey Melnik on 19.07.12.
//  Copyright (c) 2012 Unteleported. All rights reserved.
//

#import "MainController.h"

@interface MainController ()

@end

@implementation MainController
@synthesize footer;
@synthesize title;
@synthesize start_button;
@synthesize scrollview;
@synthesize right_button;
@synthesize left_button;
@synthesize page;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }


    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    page = 0;
    
    [start_button setImage:[UIImage imageNamed:@"Button_Start_down.PNG"] forState:UIControlStateHighlighted];
    [left_button setImage:[UIImage imageNamed:@"Arrow_left_hoover.png"] forState:UIControlStateHighlighted];
    [right_button setImage:[UIImage imageNamed:@"Arrow_right_hoover.png"] forState:UIControlStateHighlighted];
    
    left_button.enabled = NO;
    
    CGPoint originalCenter = footer.center;
    
    CGPoint center = footer.center;
    center.y += 90;
    footer.center = center;
    
//    center = title.center;
//    center.y -= 90;
//    title.center = center;
    
    [UIView animateWithDuration:0.5 animations:^{footer.center = originalCenter;}];
//    [UIView animateWithDuration:0.5 animations:^{title.center = title_originalCenter;}];
    
    

    
    UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"banana2.png"]];
    imageView.frame = CGRectMake(320+39, 0, 192, 283);
    
    [scrollview addSubview:imageView];
    
    imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"banana3.png"]];
    imageView.frame = CGRectMake(320*2+39, 0, 192, 283);
    
    [scrollview addSubview:imageView];    
    
    [scrollview setContentSize:CGSizeMake(320*3, scrollview.bounds.size.height)];
    scrollview.delegate = self;



	// Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [UIView animateWithDuration:0.3
                     animations:^{
                         CGPoint center = title.center;
                         center.y = -54;
                         title.center = center;
                     }
     ];
}

-(void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [UIView animateWithDuration:0.3
                     animations:^{
                         CGPoint center = title.center;
                         center.y = 54;
                         title.center = center;
                     }
     ];
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    
    CGFloat pageWidth = scrollview.frame.size.width;
    page = floor((scrollview.contentOffset.x - pageWidth / 2) / pageWidth) + 1;

    
    if(page == 0){
        left_button.enabled=NO;
    }
    
    if(page==2){
        right_button.enabled=NO;
        
    }
    
    if(page<2 && page >0){
        left_button.enabled=YES;
        right_button.enabled=YES;
    }
}

- (IBAction)right_touch:(id)sender {
    if(page < 2){
        page += 1;
        CGRect frame = scrollview.frame;
        frame.origin.x = frame.size.width * page;
        frame.origin.y = 0;
        [scrollview scrollRectToVisible:frame animated:YES];
    }

}

- (IBAction)left_touch:(id)sender {
    if(page > 0) {
        page -= 1;
        CGRect frame = scrollview.frame;
        frame.origin.x = frame.size.width * page;
        frame.origin.y = 0;
        [scrollview scrollRectToVisible:frame animated:YES];
    }
}
@end
