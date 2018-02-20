//
//  ViewController.m
//  AblyiOSJSPerformanceTest
//
//  Created by Cesare Rocchi on 19/02/2018.
//  Copyright © 2018 Ably. All rights reserved.
//

@import CocoaLumberjack;
#import "ViewController.h"
#import "UIForLumberjack.h"
#import "Ably/Ably.h"

#ifdef DEBUG
static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
static const DDLogLevel ddLogLevel = DDLogLevelError;
#endif

#define DLog DDLogDebug
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIView *logView;
@property (weak, nonatomic) IBOutlet UIWebView *webView;
@property (weak, nonatomic) IBOutlet UIButton *publishButton;
@property (strong, nonatomic) ARTRealtime *realtimeClient;
@property (strong, nonatomic) ARTRealtimeChannel *channel;
@property (strong, nonatomic) NSMutableDictionary *messages;

@end

@implementation ViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  self.messages = [NSMutableDictionary new];
  [DDLog addLogger:[DDTTYLogger sharedInstance]]; // TTY = Xcode console
  [DDLog addLogger:[UIForLumberjack sharedInstance]];
  [[UIForLumberjack sharedInstance] showLogInView:self.logView];
  [self.logView bringSubviewToFront:self.publishButton];
  
  NSString *htmlFile = [[NSBundle mainBundle] pathForResource:@"index" ofType:@"html"];
  NSString* htmlString = [NSString stringWithContentsOfFile:htmlFile encoding:NSUTF8StringEncoding error:nil];
  [self.webView loadHTMLString:htmlString baseURL: [[NSBundle mainBundle] bundleURL]];
  
  ARTClientOptions *options = [[ARTClientOptions alloc] initWithKey:@"YOUR_API_KEY"];
  options.logLevel = ARTLogLevelVerbose;
  self.realtimeClient = [[ARTRealtime alloc] initWithOptions:options];
  [self.realtimeClient.connection on:^(ARTConnectionStateChange *stateChange) {
    if (!self.realtimeClient) {
      return;
    }
    
    switch (stateChange.current) {
      case ARTRealtimeInitialized :
        DLog(@"ARTRealtimeInitialized!");
        break;
      case ARTRealtimeConnecting:
        DLog(@"ARTRealtimeConnecting!");
        break;
      case ARTRealtimeConnected:
        DLog(@"ARTRealtimeConnected!");
        [self getChannel];
        break;
      case ARTRealtimeDisconnected:
        DLog(@"ARTRealtimeDisconnected!");
        break;
      case ARTRealtimeSuspended:
        DLog(@"ARTRealtimeSuspended!");
        break;
      case ARTRealtimeClosing:
        DLog(@"ARTRealtimeClosing!");
        break;
      case ARTRealtimeClosed:
        DLog(@"ARTRealtimeClosed!");
        break;
      case ARTRealtimeFailed:
        DLog(@"ARTRealtimeFailed! %@", stateChange.reason);
        break;
      default:
        break;
    }
  }];
}

- (void)getChannel {
  self.channel = [self.realtimeClient.channels get:@"testing"];
  [self.channel subscribe:^(ARTMessage *message) {
    NSDate *now = [NSDate new];
    
    BOOL fromThisDevice = NO;
    if ([message.data isKindOfClass:[NSDictionary class]]) {
      NSDictionary *data = message.data;
      NSString* messageId = data[@"messageId"];
      NSDate *sendTime = [self.messages objectForKey:messageId];
      if (sendTime) {
        fromThisDevice = YES;
        DLog(@"[Ably] Round-trip delay: %f ms", [now timeIntervalSinceDate:sendTime] * 1000);
        DLog(@"[Ably] From iOS, (localtime - serverTs): %f ms", [now timeIntervalSinceDate:message.timestamp] * 1000);
      }
    }
    
    if (!fromThisDevice) {
      DLog(@"[Ably] From JS, (localtime - serverTs): %f ms", [now timeIntervalSinceDate:message.timestamp] * 1000);
    }
  }];
}

- (IBAction)publish:(id)sender {
  NSString *messageId = [[NSProcessInfo processInfo] globallyUniqueString];
  NSDate *now = [NSDate date];
  NSDictionary* data = @{@"from": @"iOS",
                         @"messageId" : messageId};
  self.messages[messageId] = now;
  [self.channel publish:@"update" data:data];
}


- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
}


@end
