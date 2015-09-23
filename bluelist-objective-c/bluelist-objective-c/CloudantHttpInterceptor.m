// Copyright 2014, 2015 IBM Corp. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "CloudantHttpInterceptor.h"
#import <IMFCore/IMFCore.h>

#define COOKIE_HEADER @"Cookie"

@interface CloudantHttpInterceptor ()

@property (readwrite) NSString *sessionCookie;
@property (readwrite) NSURL *refreshSessionCookieUrl;

@end

@implementation CloudantHttpInterceptor

-(instancetype)initWithSessionCookie:(NSString *)sessionCookie refreshUrl:(NSURL *)refreshSessionCookieUrl
{
    self = [super self];
    if(self){
        _sessionCookie = sessionCookie;
        _refreshSessionCookieUrl = refreshSessionCookieUrl;
    }
    return self;
}

-(CDTHTTPInterceptorContext*)interceptRequestInContext:(CDTHTTPInterceptorContext *)context
{
    if(![context.request valueForHTTPHeaderField:COOKIE_HEADER]){
        [context.request addValue:self.sessionCookie forHTTPHeaderField:COOKIE_HEADER];
    }
    return context;
}

-(CDTHTTPInterceptorContext*)interceptResponseInContext:(CDTHTTPInterceptorContext *)context
{
    //FIXMEKH handle 401.
//    if(context.response.statusCode == 401 || context.response.statusCode == 403){
//        [[IMFAuthorizationManager sharedInstance]obtainAuthorizationHeaderWithCompletionHandler:^(IMFResponse *response, NSError *error) {
//            
//            context.request addValue:<#(nonnull NSString *)#> forHTTPHeaderField:<#(nonnull NSString *)#>
//        }];
//        context.shouldRetry = YES;
//    }
    return context;
}

@end
