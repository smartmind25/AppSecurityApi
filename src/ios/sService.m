/******************************************************************************
"Copyright (c) 2015-2015, Intel Corporation
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this
    software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN
ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
"
******************************************************************************/
#ifndef DEBUG
#define NDEBUG
#endif

#import "sService.h"
#import "xss_api.h"
#import "xss_error.h"
#import "xss_types.h"

#ifndef NDEBUG
#import "xss_log.h"
#endif

#import <Foundation/Foundation.h>


#pragma mark - APIs

@implementation sService

#ifndef NDEBUG
#define XSSLOG_BRIDGE( log_level, format_str, ...)  sservice_log( LOG_SOURCE_BRIDGE, log_level, format_str, ##__VA_ARGS__)
#else
static inline void DoNothing(char const * formatStr, ... )
{
}
#define XSSLOG_BRIDGE( log_level, format_str, ...) DoNothing(format_str,  ##__VA_ARGS__)
#endif

#define STRING_ENCODING (NSUTF16LittleEndianStringEncoding)

-(NSInteger)getIntFromArgument: (CDVInvokedUrlCommand *)command
					argNumber :(NSInteger)arg
{
    if( strcmp( object_getClassName([command.arguments objectAtIndex:arg]), "__NSCFNumber" ) != 0)
    {
        return 0 ;
    }
    
    NSNumber *obj = [command.arguments objectAtIndex:arg] ;
	if (obj != nil)
    {
        NSInteger Data = (NSInteger)[obj doubleValue];
        return Data;
    }
	XSSLOG_BRIDGE(LOG_ERROR, "%s:Error access parameters", __FUNCTION__ ) ;
	return 0 ;
}

-(sservice_handle_t)getHandleFromArgument: (CDVInvokedUrlCommand *)command argNumber :(NSInteger)arg
{
	if( strcmp( object_getClassName([command.arguments objectAtIndex:arg]), "__NSCFNumber" ) != 0)
    {
        return 0 ;
    }
    NSNumber *obj = [command.arguments objectAtIndex:arg] ;
	if (obj != nil)
    {
	    sservice_handle_t DataHandle = [obj doubleValue];
		return DataHandle;
	}
	XSSLOG_BRIDGE(LOG_ERROR, "%s:Error access parameters", __FUNCTION__ ) ;
	return 0 ;
}

-(bool)checkArguments: (CDVInvokedUrlCommand *)command argNumber :(NSInteger)arg
{
	if(!command )
	{
		return false ;
	}
    if( [command.arguments count ]!= arg)
    {
        return false ;
    }
    for( int i = 0; i < arg; i++ )
    {
        if( [command.arguments objectAtIndex:i ] == nil)
        {
            return false;
        }
    }
    return true ;
}

/** Function is callback for cordova call of
 *		cordova.exec(success, failInternal, "IntelSecurity", "SecureDataCreateFromData",
 *					[defaults.data, defaults.tag, defaults.appAccessControl, defaults.deviceLocality, defaults.sensitivityLevel, defaults.creator, defaults.owners]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataCreateFromData:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:10])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
    
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        
        //Retrieve all necessary parameters.
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        NSString *dataStr = NULL;
        NSString *tagStr  = NULL;
        sservice_data_handle_t extraKey= 0;
        NSInteger appAccessControl= 0;
        NSInteger deviceLocality= 0;
        NSInteger sensitivityLevel = 0;
        NSInteger creator= 0;
        NSInteger noStore= 0;
        NSInteger noRead= 0;
        NSArray *owners= NULL;
        dataStr = [command.arguments objectAtIndex:0];
        tagStr = [command.arguments objectAtIndex:1];
        extraKey = [self getHandleFromArgument: command argNumber: 2 ];
        appAccessControl= [ self getIntFromArgument:command argNumber:3 ];
        deviceLocality= [ self getIntFromArgument:command argNumber: 4 ];
        sensitivityLevel = [self getIntFromArgument:command argNumber: 5 ];
        noStore = [ self getIntFromArgument:command argNumber:6 ];
        noRead = [ self getIntFromArgument:command argNumber:7 ];
        creator= [self getIntFromArgument:command argNumber: 8 ];
        owners= [command.arguments objectAtIndex:9];
        if(!dataStr || !owners)
        {
            res = SSERVICE_ERROR_INVALIDPOINTER ;
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, res  ) ;
        }
        
        //Convert all parameters for C code types
        unsigned long owners_num  = 0;
        sservice_persona_id_t *owners_list = NULL ;
        if( IS_SUCCESS(res))
        {
            owners_num = [owners count ];
            owners_list = calloc( sizeof( sservice_persona_id_t), owners_num) ;
            if(!owners_list)
            {
                res = SSERVICE_ERROR_INSUFFICIENTMEMORY ;
                XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, res  ) ;
            }
            else
            {
                for( int i = 0; i < owners_num; i++)
                {
                    owners_list[i] = [[owners objectAtIndex:i] integerValue]  ;
                }
            }
        }
        sservice_data_handle_t dataHandle = 0 ;
        NSMutableData *data = nil ;
        if( IS_SUCCESS(res))
        {
            data = [NSMutableData dataWithData:[dataStr dataUsingEncoding:STRING_ENCODING]];
            if(!data)
            {
                XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INVALIDPOINTER.error_or_warn_code ) ;
                res = SSERVICE_ERROR_INVALIDPOINTER ;
            }
        }
        
        //Call runtime to performe action
        if( IS_SUCCESS(res))
        {
            NSData *tag = nil ;
            if(tagStr)
            {
                tag =  [tagStr dataUsingEncoding:STRING_ENCODING ];
            }
            
            sservice_secure_data_policy_t access_policy ;
            access_policy.device_policy = (sservice_locality_type_t)deviceLocality;
            access_policy.application_policy = (sservice_application_access_control_type_t)appAccessControl ;
            access_policy.sensitivity_level = sensitivityLevel ;
            access_policy.flags.no_store = noStore;
            access_policy.flags.no_read = noRead;
            res = sservice_securedata_create_from_data( (sservice_size_t)[data length],
                                                       [data bytes ],
                                                       tag ? (sservice_size_t)[tag length]:0,
                                                       tag ? [tag bytes ]:NULL,
                                                       &access_policy, extraKey,
                                                       creator ,
                                                       (sservice_size_t)owners_num,
                                                       owners_list,
                                                       authentication_token,
                                                       &dataHandle);
        }
        if(data)
        {
            [data resetBytesInRange:NSMakeRange(0, [data length]) ];
            [data setLength:0];
        }
        if(owners_list)
        {
            free(owners_list) ;
        }
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, res.error_or_warn_code ) ;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success, Handle 0x%llx", __FUNCTION__, dataHandle ) ;
            pluginResult = [ CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:dataHandle ];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}



/** Function is callback for cordova call of
 *	cordova.exec(success, failInternal, "IntelSecurity", "SecureDataCreateFromSealedData", [sealedData]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataCreateFromSealedData:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:2])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        NSString *dataStr = NULL;
        NSData *data = NULL;
        sservice_data_handle_t extraKey= 0;
        //Retrieve all necessary parameters.
        dataStr = [command.arguments objectAtIndex:0];
        extraKey = [self getHandleFromArgument: command argNumber: 1 ];
        //Convert them to C compatible types
        if(dataStr)
        {
            data = [[NSData alloc]initWithBase64Encoding: dataStr];
        }
        if(!data)
        {
            res = SSERVICE_ERROR_INTEGRITYVIOLATIONERROR ;
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, res.error_or_warn_code ) ;
        }
        sservice_data_handle_t dataHandle = 0;
        CDVPluginResult *pluginResult = NULL ;
        
        //Call runtime to performe action
        if( IS_SUCCESS(res))
        {
            res = sservice_securedata_create_from_sealed_data( (sservice_size_t)[data length], [data bytes], extraKey, &dataHandle );
        }
        
        //Prepare callback parameters and execute necessary callback.
        if( IS_FAILED(res) )
        {
            XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, res.error_or_warn_code ) ;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:res.error_or_warn_code];
        }
        else
        {
            pluginResult = [ CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDouble:dataHandle ];
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success, handle 0x%llx", __FUNCTION__, dataHandle ) ;
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}



/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureDataGetData", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataGetData:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
    
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        sservice_size_t data_size ;
        //request data size and prepare buffer for runtime call
        res = sservice_securedata_get_size( data_handle, &data_size ) ;
        NSString *result = NULL ;
        char *data = NULL ;
        if( IS_SUCCESS(res))
        {
            data = malloc(data_size ) ;
            if( data == NULL )
            {
                res = SSERVICE_ERROR_INSUFFICIENTMEMORY ;
                XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, res.error_or_warn_code ) ;
            }
        }
        if( IS_SUCCESS(res))
        {
            //Call runtime to performe action
            res = sservice_securedata_get_data(data_handle, authentication_token, data_size, data ) ;
        }
        if( IS_SUCCESS(res))
        {
            //and prepare arguments for callback
            result = [[NSString alloc] initWithBytes:data length:data_size encoding:STRING_ENCODING];
        }
        if(data)
        {
            memset( data, 0, data_size );
            free(data);
        }
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:res.error_or_warn_code];
            XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, res.error_or_warn_code ) ;
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsString:result ];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}




/** Function is callback for cordova call of
 *		cordova.exec(success, failInternal, "IntelSecurity", "SecureDataGetSealedData", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */

- (void) SecureDataGetSealedData:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
 	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        sservice_size_t sealed_data_size = 0;
        char *sealed_data = NULL ;
        //request data size and prepare buffer for runtime call
        res = sservice_securedata_get_sealed_size( data_handle,&sealed_data_size ) ;
        if( IS_SUCCESS(res))
        {
            sealed_data = malloc( sealed_data_size) ;
            if(!sealed_data)
            {
                res = SSERVICE_ERROR_INSUFFICIENTMEMORY ;
            }
        }
        //Call runtime to performe action
        if( IS_SUCCESS(res))
        {
            res = sservice_securedata_get_sealed_data( data_handle,sealed_data_size,sealed_data );
        }
        NSString *base64Out = nil ;
        if( IS_SUCCESS(res))
        {
            NSData *temp = [[ NSData alloc ] initWithBytesNoCopy:sealed_data length:sealed_data_size ];
            base64Out = [temp base64EncodedString] ;
        }
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus : CDVCommandStatus_OK messageAsString:
                            base64Out];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

/** Function is callback for cordova call of
 *		cordova.exec(success, failInternal, "IntelSecurity", "SecureDataChangeExtraKey", [instanceID, extraKeyInstanceID]);
 * @param [in] command - instanceID for the secureData instance that the key in the extraKeyInstanceID should be changed too.
 * @return nothing; result is passed to callback using self.commandDelegate
 */

- (void) SecureDataChangeExtraKey:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:2])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t instanceID = [self getHandleFromArgument: command argNumber: 0 ];
		sservice_handle_t extra_key_instanceID = [self getHandleFromArgument: command argNumber: 1 ];
        res = sservice_securedata_change_extraKey(instanceID, extra_key_instanceID);
		
		//Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus : CDVCommandStatus_OK];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureDataGetTag", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataGetTag:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        sservice_size_t tag_size =0;
        //request data size and prepare buffer for runtime call
        res = sservice_securedata_get_tag_size(data_handle, &tag_size);
        char *tag = NULL;
        
        if( IS_SUCCESS(res))
        {
            if(tag_size > 0 )
            {
                tag = calloc( 1, tag_size) ;
                if(!tag)
                {
                    res = SSERVICE_ERROR_INSUFFICIENTMEMORY ;
                }
            }
        }
        NSString *result = @"";
        //Call runtime to performe action
        if( IS_SUCCESS(res) && tag_size > 0 )
        {
            res = sservice_securedata_get_tag(data_handle,tag_size,tag );
            if( IS_SUCCESS(res))
            {
                result = [[NSString alloc] initWithBytes:tag length:tag_size encoding:STRING_ENCODING];
            }
        }
        if(tag)
        {
            free( tag ) ;
        }
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus : CDVCommandStatus_OK messageAsString:result];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}





/** Function is callback for cordova call of
 *         ccordova.exec(success, failInternal, "IntelSecurity", "SecureDataGetPolicy", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataGetPolicy:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
    //this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        sservice_secure_data_policy_t access_policy ;
        memset( &access_policy, 0, sizeof(access_policy) );
        //Call runtime to performe action
        res = sservice_securedata_get_policy(data_handle, &access_policy);
        NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
        [result setObject:[NSNumber numberWithInteger:access_policy.application_policy] forKey:@"appAccessControl"];
        [result setObject:[NSNumber numberWithInteger:access_policy.device_policy] forKey:@"deviceLocality"];
        [result setObject:[NSNumber numberWithInteger:access_policy.sensitivity_level] forKey:@"sensitivityLevel"];
	[result setObject:[NSNumber numberWithInteger:access_policy.flags.no_store] forKey:@"noStore"];
	[result setObject:[NSNumber numberWithInteger:access_policy.flags.no_read] forKey:@"noRead"];
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
        }
	    // Execute sendPluginResult on this plugin's commandDelegate, passing in the ...
        // ... instance of CDVPluginResult
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}



/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureDataGetOwners", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataGetOwners:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        sservice_size_t number_of_owners = 0 ;
        sservice_persona_id_t* owners_buffer = NULL ;
        //request data size and prepare buffer for runtime call
        res = sservice_securedata_get_number_of_owners(data_handle, &number_of_owners );
        if( IS_SUCCESS(res) )
        {
            owners_buffer = calloc( sizeof(sservice_persona_id_t), number_of_owners ) ;
            if(!owners_buffer)
            {
                res = SSERVICE_ERROR_INSUFFICIENTMEMORY ;
            }
        }
        //Call runtime to performe action
        if( IS_SUCCESS(res) )
        {
            res = sservice_securedata_get_owners(data_handle, sizeof(sservice_persona_id_t)*number_of_owners, owners_buffer);
        }
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL;
        if( IS_SUCCESS(res) )
        {
            //Convert results to ObjectiveC NSArray to return to cordova runtime
            NSMutableArray *result = [[NSMutableArray alloc] initWithCapacity:number_of_owners];
            for( int i = 0; i < number_of_owners; i++ )
            {
                [result addObject:[NSNumber numberWithInteger:owners_buffer[i]]];
            }
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:result ];
        }
        else
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        if(owners_buffer)
        {
            free( owners_buffer) ;
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}




/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureDataGetCreator", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataGetCreator:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        sservice_persona_id_t creator ;
        //Prepare callback parameters and execute necessary callback.
        res = sservice_securedata_get_creator(data_handle, &creator );
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK messageAsDouble:creator];
        }
        // Execute sendPluginResult on this plugin's commandDelegate, passing in the ...
        // ... instance of CDVPluginResult
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}



/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureDataDestroy", [instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureDataDestroy:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 0 ];
        //Prepare callback parameters and execute necessary callback.
        res = sservice_securedata_destroy( data_handle ) ;
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK ];
        }
        // Execute sendPluginResult on this plugin's commandDelegate, passing in the ...
        // ... instance of CDVPluginResult
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}


/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureStorageRead", [defaults.id, defaults.storageType]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureStorageRead:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:3])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        NSString *storageId = [command.arguments objectAtIndex:0];
        //Retrieve all necessary parameters.
        NSInteger storageType = [self getIntFromArgument: command argNumber: 1 ];
        sservice_data_handle_t extraKey = [self getHandleFromArgument: command argNumber: 2 ];
        sservice_data_handle_t data_handle ;
        //Prepare callback parameters and execute necessary callback.
        res = sservice_securestorage_read([storageId UTF8String],
                                          (sservice_secure_storage_type_t)storageType, extraKey, &data_handle );
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus    : CDVCommandStatus_OK
                                                  messageAsDouble:data_handle
                            ];
        }
        // Execute sendPluginResult on this plugin's commandDelegate, passing in the ...
        // ... instance of CDVPluginResult
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}





/** Function is callback for cordova call of
 
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureStorageWrite", [defaults.id, defaults.storageType,defaults.data, defaults.tag, defaults.appAccessControl, defaults.deviceLocality, defaults.sensitivityLevel, defaults.creator, defaults.owners]);
 
 * @param [in] command - array of parameters, passed by Cordova runtime.
 
 * @return nothing; result is passed to callback using self.commandDelegate
 
 */

- (void) SecureStorageWrite:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    if( ![self checkArguments:command argNumber:12])
	{
        XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	}
    
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        NSString *storageId = [command.arguments objectAtIndex:0];
        NSInteger storageType = [self getIntFromArgument: command argNumber: 1 ];
        sservice_data_handle_t extraKey= 0;
        NSString *dataStr = NULL;
        NSString *tagStr  = NULL;
        NSInteger appAccessControl= 0;
        NSInteger deviceLocality= 0;
        NSInteger sensitivityLevel = 0;
        NSInteger creator= 0;
        NSInteger noStore= 0;
        NSInteger noRead= 0;
        NSArray *owners= NULL;
        
        if( command )
        {
            dataStr = [command.arguments objectAtIndex:2];
            tagStr = [command.arguments objectAtIndex:3];
            extraKey = [self getHandleFromArgument: command argNumber: 4 ];
            appAccessControl= [ self getIntFromArgument:command argNumber:5 ];
            deviceLocality= [ self getIntFromArgument:command argNumber: 6 ];
            sensitivityLevel = [self getIntFromArgument:command argNumber: 7 ];
            noStore = [ self getIntFromArgument:command argNumber:8 ];
            noRead = [ self getIntFromArgument:command argNumber:9 ];
            creator= [self getIntFromArgument:command argNumber: 10 ];
            owners= [command.arguments objectAtIndex:11];
            
            if(!dataStr || !owners)
            {
                res = SSERVICE_ERROR_INVALIDPOINTER ;
                XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, res  ) ;
            }
        }
        
        //Convert all parameters for C code types
        unsigned long owners_num  = 0;
        sservice_persona_id_t *owners_list = NULL ;
        if( IS_SUCCESS(res))
        {
            owners_num = [owners count ];
            owners_list = calloc( sizeof( sservice_persona_id_t), owners_num) ;
            if(!owners_list)
            {
                res = SSERVICE_ERROR_INSUFFICIENTMEMORY ;
                XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, res  ) ;
            }
            else
            {
                for( int i = 0; i < owners_num; i++)
                    owners_list[i] = [[owners objectAtIndex:i] integerValue]  ;
            }
        }
        NSData *data = NULL ;
        if( IS_SUCCESS(res))
        {
            data = [dataStr dataUsingEncoding:STRING_ENCODING ];
            if(!data)
            {
                XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INVALIDPOINTER ) ;
                res = SSERVICE_ERROR_INVALIDPOINTER ;
            }
        }
        
        //Call runtime to performe action
        if( IS_SUCCESS(res))
        {
            NSData *tag = nil ;
            if(tagStr)
            {
                tag =  [tagStr dataUsingEncoding:STRING_ENCODING ];
            }
            sservice_secure_data_policy_t access_policy ;
            access_policy.device_policy = (sservice_locality_type_t)deviceLocality;
            access_policy.application_policy = (sservice_application_access_control_type_t) appAccessControl ;
            access_policy.sensitivity_level = sensitivityLevel ;
            access_policy.flags.no_store = noStore;
            access_policy.flags.no_read = noRead;
            
            XSSLOG_BRIDGE(LOG_INFO, "Entering to %s, storageID: %p, type: %d", __FUNCTION__, storageId, storageType) ;
            res = sservice_securestorage_write( [storageId UTF8String],
                                               (sservice_secure_storage_type_t)storageType,
                                               (sservice_size_t)[data length],
                                               [data bytes ],
                                               tag ? (sservice_size_t)[tag length]:0,
                                               tag ? [tag bytes ]:NULL,
                                               extraKey, &access_policy, creator,
                                               (sservice_size_t)owners_num, owners_list,
                                               authentication_token
                                               );
        }
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK ];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}







/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureStorageWriteSecureData", [defaults.id, defaults.storageType, defaults.instanceID]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureStorageWriteSecureData:(CDVInvokedUrlCommand *)command
{
    if( ![self checkArguments:command argNumber:3])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        NSString *storageId = [command.arguments objectAtIndex:0];
        NSInteger storageType = [self getIntFromArgument: command argNumber: 1 ];
        sservice_handle_t data_handle = [self getHandleFromArgument: command argNumber: 2 ];
        XSSLOG_BRIDGE(LOG_INFO, "Entering to %s, storageID: %p, type: %d, data %d", __FUNCTION__, storageId, storageType, data_handle ) ;
        
        //Prepare callback parameters and execute necessary callback.
        res = sservice_securestorage_write_securedata(
                                        [storageId UTF8String],
                                        (sservice_secure_storage_type_t)storageType,
                                        data_handle ) ;
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK ];
        }
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}


/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "SecureStorageDelete", [defaults.id, defaults.storageType]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) SecureStorageDelete:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    
    if( ![self checkArguments:command argNumber:2])
	{
	XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt:SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
	//this call will move the rest of the procedure to another thread
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        //Retrieve all necessary parameters.
        NSString *storageId = [command.arguments objectAtIndex:0];
        NSInteger storageType = [self getIntFromArgument: command argNumber: 1 ];
        XSSLOG_BRIDGE(LOG_INFO, "Entering to %s, storageID: %p, type: %d", __FUNCTION__, storageId, storageType ) ;
        //Prepare callback parameters and execute necessary callback.
        res = sservice_securestorage_delete(
                                            [storageId UTF8String],
                                            (sservice_secure_storage_type_t)storageType	);
        
        //Prepare callback parameters and execute necessary callback.
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                                messageAsInt:res.error_or_warn_code];
        }
        else
        {
            XSSLOG_BRIDGE(LOG_INFO, "Exiting from %s, Success", __FUNCTION__ ) ;
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK ];
        }
        // Execute sendPluginResult on this plugin's commandDelegate, passing in the ...
        // ... instance of CDVPluginResult
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}





#ifndef NDEBUG
/** Function is callback for cordova call of
 *         cordova.exec(success, failInternal, "IntelSecurity", "??????", [log_level]);
 * @param [in] command - array of parameters, passed by Cordova runtime.
 * @return nothing; result is passed to callback using self.commandDelegate
 */
- (void) log:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
	//Retrieve all necessary parameters.
	NSString *log = [command.arguments objectAtIndex:0] ;
	//Prepare callback parameters and execute necessary callback.
	CDVPluginResult *pluginResult = NULL ;
    
	//Prepare callback parameters and execute necessary callback.
	sservice_log( LOG_SOURCE_JS, LOG_INFO, "%s", [log cStringUsingEncoding:[NSString defaultCStringEncoding]]) ;
    pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK ];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) unitTest:(CDVInvokedUrlCommand *)command
{
	//Check input parameter. Probably not necessary
    if( ![self checkArguments:command argNumber:1])
	{
		XSSLOG_BRIDGE(LOG_ERROR, "Exiting from %s, error 0x%x", __FUNCTION__, SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code ) ;
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsInt: SSERVICE_ERROR_INTERNAL_ERROR.error_or_warn_code];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return ;
	}
    [self.commandDelegate runInBackground:^{
        sservice_result_t res = SSERVICE_SUCCESS_NOINFO ;
        
        sservice_debug_unit_test() ;
        CDVPluginResult *pluginResult = NULL ;
        if( IS_FAILED(res) )
        {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR
                                             messageAsString:[NSString stringWithFormat:@"%d", res.error_or_warn_code]];
        }
        else
        {
            pluginResult = [ CDVPluginResult resultWithStatus: CDVCommandStatus_OK ];
        }
        // Execute sendPluginResult on this plugin's commandDelegate, passing in the ...
        // ... instance of CDVPluginResult
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}
#endif
@end
