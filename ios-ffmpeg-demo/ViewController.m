//
//  ViewController.m
//  ios-ffmpeg-demo
//
//  Created by 杨庆人 on 2020/8/18.
//  Copyright © 2020 杨庆人. All rights reserved.
//

#import "ViewController.h"
#import "FFmpegViewController.h"
#import "VideoToolBoxViewController.h"
#import "ConvertViewController.h"

@interface ViewController ()
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, copy) NSArray <NSString *> *dataArray;

@end

@implementation ViewController

- (UITableView *)tableView
{
    if (!_tableView) {
        _tableView = [[UITableView alloc] initWithFrame:self.view.bounds];
        _tableView.dataSource = (id <UITableViewDataSource>)self;
        _tableView.delegate = (id <UITableViewDelegate>)self;
        _tableView.tableFooterView = [UIView new];
    }
    return _tableView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;

    self.dataArray = @[@"FFpmeg 解码 MOV",
                       @"VideoToolBox h264 编码,解码"
                       ];
    
    [self.view addSubview:self.tableView];
    
    // Do any additional setup after loading the view.
}

//- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
//{
//    if (1 == indexPath.row) {
//        return 88;
//    }
//    else {
//        return 44;
//    }
//}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identity = @"UITableViewCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identity];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identity];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    cell.textLabel.text = self.dataArray[indexPath.row];
    cell.textLabel.adjustsFontSizeToFitWidth = YES;
    cell.textLabel.textColor = UIColor.blackColor;
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.row) {
        case 0:
            {
                FFmpegViewController *vc = [[FFmpegViewController alloc] init];
                [self.navigationController pushViewController:vc animated:YES];
            }
            break;
            
        case 1:
            {
                VideoToolBoxViewController *vc = [[VideoToolBoxViewController alloc] init];
                [self.navigationController pushViewController:vc animated:YES];
            }
            break;
            
        case 2:
            {
                ConvertViewController *vc = [[ConvertViewController alloc] init];
                [self.navigationController pushViewController:vc animated:YES];
            }
            
            break;
        default:
            break;
    }
}

@end
