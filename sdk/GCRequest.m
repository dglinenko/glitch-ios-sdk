/*-
 *  Glitch iOS SDK
 *  
 *  Copyright 2011 Tiny Speck, Inc.
 *  Created by Brady Archambo.
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License. 
 *
 *  See more about Glitch at http://www.glitch.com
 *  http://www.tinyspeck.com
 */


#import "GCRequest.h"
#import "SBJson.h"


static NSString * const GCUserAgent = @"glitch-ios-sdk";
static NSString * const GCAPIUrlPrefix = @"http://api.glitch.com/simple/";
static NSTimeInterval const GCTimeout = 120;


@implementation GCRequest


#pragma mark - Initialization

// Do not call this directly - call Glitch, which will call this lower-level method
//
// Get a GCRequest object with a specificed method,
// delegate to call when request/response events occur,
// and any parameters passed in for the request.
+ (GCRequest *)requestWithMethod:(NSString*)method
                        delegate:(id<GCRequestDelegate>)delegate
                          params:(NSDictionary*)params
                  additionalData:(NSDictionary*)additionalData
{
    GCRequest * request = [[GCRequest alloc] init];
    request.method = method;
    request.url = [NSString stringWithFormat:@"%@%@",GCAPIUrlPrefix,method];
    request.params = params;
    request.requestDelegate = delegate;
    request.additionalData = additionalData;
    
    return request;
}


#pragma mark - Interacting with the API

// Once you have the request object, call this to actually perform the asynchronous request
// Creates and starts a connection with the Glitch API
- (void)connect
{
    // Serialize URL with parameters if we have them, otherwise, use our base URL
    NSString * url = self.params != nil ? [GCRequest serializeURL:self.url params:self.params] : self.url;
    
    // Create the request that we're going to send
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:GCTimeout];
    [request setHTTPMethod:@"GET"];
    [request setValue:GCUserAgent forHTTPHeaderField:@"User-Agent"]; // Set our user agent so the server knows that we're calling from the iOS SDK
    
    // Initialize and start the connection
    self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:YES];
}


// Parse the data from the server into an object using JSON parser
- (id)parseResponse:(NSData *)data
{ 
    // Transform the data into a string
    NSString * responseString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ;
    
    // If the data transformation succeeds, parse the JSON into an object
    if (responseString)
    {
        SBJsonParser * jsonParser = [SBJsonParser new];
        return [jsonParser objectWithString:responseString];
    }
    
    return nil;
}


#pragma mark - Utility

+ (NSString *)urlEncodeString:(NSString*)string {

	return (__bridge_transfer NSString *)CFURLCreateStringByAddingPercentEscapes(NULL,
                                                               (__bridge CFStringRef)string,
                                                               NULL,
                                                               (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ",
                                                               CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}


+ (NSString*)serializeURL:(NSString*)url params:(NSDictionary*)params
{
    NSString * preparedURL = [url stringByAppendingString:@"?"];
    
    return [preparedURL stringByAppendingString:[GCRequest serializeParams:params]];
}


+ (NSString*)serializeParams:(NSDictionary*)params
{
    NSMutableArray * arguments = [NSMutableArray arrayWithCapacity:[params count]];
    
    for (NSString * key in params)
    {
        [arguments addObject:[NSString stringWithFormat:@"%@=%@",
                              [GCRequest urlEncodeString:key],
                              [GCRequest urlEncodeString:[[params objectForKey:key] description]]]];
    }
    
    return [arguments componentsJoinedByString:@"&"];
}


+ (NSDictionary*)deserializeParams:(NSString*)fragment
{
    NSArray * pairs = [fragment componentsSeparatedByString:@"&"];
	
    NSMutableDictionary * params = [[NSMutableDictionary alloc] init];
	
    for (NSString * pair in pairs) {
		NSArray * keyValue = [pair componentsSeparatedByString:@"="];
		NSString * value = [[keyValue objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
		[params setObject:value forKey:[keyValue objectAtIndex:0]];
	}
    
    return params;
}


#pragma mark - NSURL Delegate Stuffs

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	self.receivedResponseData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
	[self.receivedResponseData appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    id result = [self parseResponse:self.receivedResponseData];
    
    if (result)
    {
        if ([self.requestDelegate respondsToSelector:@selector(requestFinished:withResult:)])
        {
            [self.requestDelegate requestFinished:self withResult:result];
        }
    }
    
     self.connection = nil;
	 self.receivedResponseData = nil;
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if ([self.requestDelegate respondsToSelector:@selector(requestFailed:withError:)])
    {
        [self.requestDelegate requestFailed:self withError:error];
    }
    
	self.connection = nil;
	self.receivedResponseData = nil;
}

@end