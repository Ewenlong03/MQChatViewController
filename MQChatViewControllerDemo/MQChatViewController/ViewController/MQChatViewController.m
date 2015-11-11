//
//  MQChatViewController.m
//  MeiQiaSDK
//
//  Created by ijinmao on 15/10/28.
//  Copyright © 2015年 MeiQia Inc. All rights reserved.
//

#import "MQChatViewController.h"
#import "MQChatViewTableDataSource.h"
#import "MQChatViewService.h"
#import "MQCellModelProtocol.h"
#import "MQDeviceFrameUtil.h"
#import "MQInputBar.h"
#import "MQToast.h"
#import "MQRecordView.h"
#import "VoiceConverter.h"

static CGFloat const kMQChatViewInputBarHeight = 50.0;
#ifdef INCLUDE_MEIQIA_SDK
static NSInteger const kMQChatNavTitleViewTag       = 2000;
static NSInteger const kMQChatNavTitleLabelTag      = 2001;
static NSInteger const kMQChatNavTitleIndicatorTag  = 2002;
@interface MQChatViewController () <UITableViewDelegate, MQChatViewServiceDelegate, MQInputBarDelegate, UIImagePickerControllerDelegate, MQChatTableViewDelegate, MQChatCellDelegate, MQRecordViewDelegate, MQServiceToViewInterfaceErrorDelegate>
#else
@interface MQChatViewController () <UITableViewDelegate, MQChatViewServiceDelegate, MQInputBarDelegate, UIImagePickerControllerDelegate, MQChatTableViewDelegate, MQChatCellDelegate, MQRecordViewDelegate>
#endif

@end

@implementation MQChatViewController {
    MQChatViewConfig *chatViewConfig;
    MQChatViewTableDataSource *tableDataSource;
    MQChatViewService *chatViewService;
    MQInputBar *chatInputBar;
    MQRecordView *recordView;
    CGSize viewSize;
}

- (void)dealloc {
    NSLog(@"清除chatViewController");
    [chatViewConfig setConfigToDefault];
}

- (instancetype)initWithChatViewManager:(MQChatViewConfig *)config {
    if (self = [super init]) {
        chatViewConfig = config;
    }
    return  self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    viewSize = self.view.frame.size;
    [self setNavBar];
    [self initChatTableView];
    [self initchatViewService];
    [self initInputBar];
    [self initTableViewDataSource];
    chatViewService.chatViewWidth = self.chatTableView.frame.size.width;
    [chatViewService sendLocalWelcomeChatMessage];
    
#ifdef INCLUDE_MEIQIA_SDK
    [self updateNavBarTitle:@"正在分配客服..."];
#endif
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [chatViewConfig setConfigToDefault];
    [[NSNotificationCenter defaultCenter] postNotificationName:MQAudioPlayerDidInterruptNotification object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    //更新view frame
    viewSize = self.view.frame.size;
    [self updateContentViewsFrame];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)dismissChatModalView {
    [self dismissViewControllerAnimated:true completion:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma 添加消息通知的observer
- (void)setNotificationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(resignKeyboardFirstResponder:) name:MQChatViewKeyboardResignFirstResponderNotification object:nil];
}

#pragma 消息通知observer的处理函数
- (void)resignKeyboardFirstResponder:(NSNotification *)notification {
    [self.view endEditing:true];
}

#pragma MQChatTableViewDelegate
- (void)didTapChatTableView:(UITableView *)tableView {
    [self.view endEditing:true];
}

//下拉刷新，获取以前的消息
- (void)startLoadingTopMessagesInTableView:(UITableView *)tableView {
#ifndef INCLUDE_MEIQIA_SDK
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.chatTableView finishLoadingTopRefreshViewWithMessagesNumber:1];
    });
#endif
}

//上拉刷新，获取更新的消息
- (void)startLoadingBottomMessagesInTableView:(UITableView *)tableView {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.chatTableView finishLoadingBottomRefreshView];
    });
}

#pragma 编辑导航栏
- (void)setNavBar {
#ifndef INCLUDE_MEIQIA_SDK
    UIButton *loadMessageBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    loadMessageBtn.frame = CGRectMake(0, 0, 62, 22);
    [loadMessageBtn setTitle:@"收取消息" forState:UIControlStateNormal];
    [loadMessageBtn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    loadMessageBtn.titleLabel.font = [UIFont systemFontOfSize:12.0];
    loadMessageBtn.backgroundColor = [UIColor clearColor];
    [loadMessageBtn addTarget:self action:@selector(tapLoadMessageBtn:) forControlEvents:UIControlEventTouchUpInside];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:loadMessageBtn];
#endif
}
#ifndef INCLUDE_MEIQIA_SDK
- (void)tapLoadMessageBtn:(id)sender {
    [chatViewService loadLastMessage];
    [self chatTableViewScrollToBottom];
}
#endif

#pragma 初始化viewModel
- (void)initchatViewService {
    chatViewService = [[MQChatViewService alloc] init];
    chatViewService.delegate = self;
#ifdef INCLUDE_MEIQIA_SDK
    chatViewService.errorDelegate = self;
#endif
}

#pragma 初始化tableView dataSource
- (void)initTableViewDataSource {
//    tableDataSource = [[MQChatViewTableDataSource alloc] initWithTableView:self.chatTableView chatViewService:chatViewService];
    tableDataSource = [[MQChatViewTableDataSource alloc] initWithChatViewService:chatViewService];
    tableDataSource.chatCellDelegate = self;
    self.chatTableView.dataSource = tableDataSource;
}

#pragma 初始化所有Views
/**
 * 初始化聊天的tableView
 */
- (void)initChatTableView {
    [self setChatTableViewFrame];
    self.chatTableView = [[MQChatTableView alloc] initWithFrame:chatViewConfig.chatViewFrame style:UITableViewStylePlain];
    self.chatTableView.chatTableViewDelegate = self;
    self.chatTableView.delegate = self;
    [self.view addSubview:self.chatTableView];
}

/**
 * 初始化聊天的inpur bar
 */
- (void)initInputBar {
    CGRect inputBarFrame = CGRectMake(self.chatTableView.frame.origin.x, self.chatTableView.frame.origin.y+self.chatTableView.frame.size.height, self.chatTableView.frame.size.width, kMQChatViewInputBarHeight);
    chatInputBar = [[MQInputBar alloc] initWithFrame:inputBarFrame
                                           superView:self.view
                                           tableView:self.chatTableView
                                     enabelSendVoice:[MQChatViewConfig sharedConfig].enableVoiceMessage
                                     enableSendImage:[MQChatViewConfig sharedConfig].enableImageMessage
                                    photoSenderImage:[MQChatViewConfig sharedConfig].photoSenderImage
                                    voiceSenderImage:[MQChatViewConfig sharedConfig].voiceSenderImage
                                 keyboardSenderImage:[MQChatViewConfig sharedConfig].keyboardSenderImage];
    chatInputBar.delegate = self;
    [self.view addSubview:chatInputBar];
    self.inputBarView = chatInputBar;
    self.inputBarTextView = chatInputBar.textView.internalTextView;
}

#pragma UITableViewDelegate
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    id<MQCellModelProtocol> cellModel = [chatViewService.cellModels objectAtIndex:indexPath.row];
    return [cellModel getCellHeight];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.view endEditing:YES];
}

#pragma UIScrollViewDelegate
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.chatTableView scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.chatTableView scrollViewDidScroll:scrollView];
}

#pragma MQChatViewServiceDelegate
- (void)didGetHistoryMessagesWithMessagesNumber:(NSInteger)messageNumber {
    [self.chatTableView finishLoadingTopRefreshViewWithMessagesNumber:messageNumber];
    [self.chatTableView reloadData];
}

- (void)didUpdateCellModelWithIndexPath:(NSIndexPath *)indexPath {
    [self.chatTableView reloadData];
//    [self tableView:self.chatTableView heightForRowAtIndexPath:indexPath];
//    [self.chatTableView updateTableViewAtIndexPath:indexPath];
}

- (void)reloadChatTableView {
    [self.chatTableView reloadData];
}

- (void)didScheduleClientWithViewTitle:(NSString *)viewTitle {
    [self updateNavBarTitle:viewTitle];
}

- (void)didReceiveMessage {
    [self chatTableViewScrollToBottom];
}

#pragma MQInputBarDelegate
-(BOOL)sendTextMessage:(NSString*)text {
    if (self.isInitializing) {
        [MQToast showToast:@"正在分配客服，请稍后发送消息" duration:3 window:self.view];
        return NO;
    }
    [chatViewService sendTextMessageWithContent:text];
    [self chatTableViewScrollToBottom];
    return YES;
}

-(void)sendImageWithSourceType:(UIImagePickerControllerSourceType *)sourceType {
    if (TARGET_IPHONE_SIMULATOR && (int)sourceType == UIImagePickerControllerSourceTypeCamera){
        [MQToast showToast:@"当前设备没有相机" duration:2 window:self.view];
        NSLog(@"当前设备没有相机");
        return;
    }
    //兼容ipad打不开相册问题，使用队列延迟，规避ios8的警惕性
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.sourceType               = (int)sourceType;
        picker.delegate                 = (id)self;
        [self presentViewController:picker animated:YES completion:nil];
    }];
}

-(void)inputting:(NSString*)content {
    //用户正在输入
    [chatViewService sendUserInputtingWithContent:content];
    [self chatTableViewScrollToBottom];
}

-(void)chatTableViewScrollToBottom {
    NSInteger lastCellIndex = chatViewService.cellModels.count;
    if (lastCellIndex == 0) {
        return;
    }
    [self.chatTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:lastCellIndex-1 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:true];
}

-(void)beginRecord:(CGPoint)point {
    if (TARGET_IPHONE_SIMULATOR){
        [MQToast showToast:@"当前设备无法完成录音" duration:2 window:self.view];
        NSLog(@"当前设备无法完成录音");
        return;
    }
    
    //停止播放的通知
    [[NSNotificationCenter defaultCenter] postNotificationName:MQAudioPlayerDidInterruptNotification object:nil];
    
    //如果开发者不自定义录音界面，则将播放界面显示出来
    if (!recordView) {
        recordView = [[MQRecordView alloc] initWithFrame:CGRectMake(0,
                                                                    0,
                                                                    self.chatTableView.frame.size.width,
                                                                    viewSize.height - chatInputBar.frame.size.height)
                                       maxRecordDuration:[MQChatViewConfig sharedConfig].maxVoiceDuration];
        recordView.recordViewDelegate = self;
        if ([MQChatViewConfig sharedConfig].enableCustomRecordView) {
            [self.view addSubview:recordView];
        }
    }
    [recordView reDisplayRecordView];
    [recordView startRecording];
}

-(void)finishRecord:(CGPoint)point {
    [recordView stopRecord];
    [self didEndRecord];
}

-(void)cancelRecord:(CGPoint)point {
    [recordView cancelRecording];
    [self didEndRecord];
}

-(void)changedRecordViewToCancel:(CGPoint)point {
    recordView.revoke = true;
}

-(void)changedRecordViewToNormal:(CGPoint)point {
    recordView.revoke = false;
}

- (void)didEndRecord {

}

#pragma MQRecordViewDelegate
- (void)didFinishRecordingWithAMRFilePath:(NSString *)filePath {
    [chatViewService sendVoiceMessageWithAMRFilePath:filePath];
    [self chatTableViewScrollToBottom];
}

- (void)didUpdateVolumeInRecordView:(UIView *)recordView volume:(CGFloat)volume {

}

#pragma UIImagePickerControllerDelegate
-(void)imagePickerController:(UIImagePickerController*)picker didFinishPickingMediaWithInfo:(NSDictionary *)info{
    NSString *type          = [info objectForKey:UIImagePickerControllerMediaType];
    //当选择的类型是图片
    if (![type isEqualToString:@"public.image"]) {
        return;
    }
    UIImage *image          = [info objectForKey:@"UIImagePickerControllerOriginalImage"];
    [picker dismissViewControllerAnimated:YES completion:nil];
    [chatViewService sendImageMessageWithImage:image];
    [self chatTableViewScrollToBottom];
}

-(void)imagePickerControllerDidCancel:(UIImagePickerController *)picker{
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma MQChatCellDelegate
- (void)showToastViewInCell:(UITableViewCell *)cell toastText:(NSString *)toastText {
    [MQToast showToast:toastText duration:1.0 window:self.view];
}

- (void)resendMessageInCell:(UITableViewCell *)cell resendData:(NSDictionary *)resendData {
    //先删除之前的消息
    NSIndexPath *indexPath = [self.chatTableView indexPathForCell:cell];
    [chatViewService resendMessageAtIndex:indexPath.row resendData:resendData];
    [self chatTableViewScrollToBottom];
}

- (void)didSelectMessageInCell:(UITableViewCell *)cell messageContent:(NSString *)content selectedContent:(NSString *)selectedContent {

}

#pragma ios7以下系统的横屏的事件
- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    NSLog(@"willAnimateRotationToInterfaceOrientation");
    viewSize = CGSizeMake(self.view.frame.size.width, self.view.frame.size.height);
    [self updateContentViewsFrame];
}

#pragma ios8以上系统的横屏的事件
- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         [[UIApplication sharedApplication] setStatusBarHidden:NO];
         
     } completion:^(id<UIViewControllerTransitionCoordinatorContext> context)
     {
         
     }];
    viewSize = size;
    [self updateContentViewsFrame];
}

//更新viewConroller中所有的view的frame
- (void)updateContentViewsFrame {
    //更新view
    self.view.frame = CGRectMake(0, 0, viewSize.width, viewSize.height);
    //更新tableView的frame
    [self setChatTableViewFrame];
    //更新cellModel的frame
    chatViewService.chatViewWidth = viewSize.width;
    [chatViewService updateCellModelsFrame];
    [self.chatTableView reloadData];
    //更新inputBar的frame
    CGRect inputBarFrame = CGRectMake(self.chatTableView.frame.origin.x, self.chatTableView.frame.origin.y+self.chatTableView.frame.size.height, self.chatTableView.frame.size.width, kMQChatViewInputBarHeight);
    [chatInputBar updateFrame:inputBarFrame];
    //更新recordView的frame
    CGRect recordViewFrame = CGRectMake(0,
                                        0,
                                        self.chatTableView.frame.size.width,
                                        viewSize.height - chatInputBar.frame.size.height);
    [recordView updateFrame:recordViewFrame];
}

- (void)setChatTableViewFrame {
    //更新tableView的frame
    if (!chatViewConfig.isCustomizedChatViewFrame) {
        chatViewConfig.chatViewFrame = CGRectMake(0, 0, viewSize.width, viewSize.height - kMQChatViewInputBarHeight);
        [self.chatTableView updateFrame:chatViewConfig.chatViewFrame];;
    }
}

#pragma 横屏后，仍然显示statusBar
- (BOOL)prefersStatusBarHidden {
    return NO;
}

#ifdef INCLUDE_MEIQIA_SDK
#pragma MQServiceToViewInterfaceErrorDelegate 后端返回的数据的错误委托方法
- (void)getLoadHistoryMessageError {
    [MQToast showToast:@"抱歉，获取历史消息出了点儿小问题，请重新试下~" duration:1.0 window:self.view];
}

/**
 *  根据是否正在分配客服，更新导航栏title
 *
 *  @param isScheduling 是否正在分配客服
 */
- (void)updateNavBarTitle:(NSString *)title {
//    if (self.navigationItem.titleView.tag != kMQChatNavTitleViewTag) {
//        //生成导航栏title
//    }
    self.navigationItem.title = title;
}


#endif


@end
