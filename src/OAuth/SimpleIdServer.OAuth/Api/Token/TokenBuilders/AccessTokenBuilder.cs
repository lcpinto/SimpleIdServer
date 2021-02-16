﻿// Copyright (c) SimpleIdServer. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.
using Microsoft.AspNetCore.WebUtilities;
using Microsoft.Extensions.Options;
using Newtonsoft.Json.Linq;
using SimpleIdServer.Jwt.Extensions;
using SimpleIdServer.Jwt.Jws;
using SimpleIdServer.OAuth.Authenticate.Handlers;
using SimpleIdServer.OAuth.DTOs;
using SimpleIdServer.OAuth.Extensions;
using SimpleIdServer.OAuth.Helpers;
using SimpleIdServer.OAuth.Jwt;
using SimpleIdServer.OAuth.Options;
using System;
using System.Collections.Generic;
using System.Security.Cryptography;
using System.Threading;
using System.Threading.Tasks;

namespace SimpleIdServer.OAuth.Api.Token.TokenBuilders
{
    public class AccessTokenBuilder : ITokenBuilder
    {
        private readonly IGrantedTokenHelper _grantedTokenHelper;
        private readonly IJwtBuilder _jwtBuilder;
        private readonly OAuthHostOptions _oauthHostOptions;

        public AccessTokenBuilder(IGrantedTokenHelper grantedTokenHelper, IJwtBuilder jwtBuilder, IOptions<OAuthHostOptions> options)
        {
            _grantedTokenHelper = grantedTokenHelper;
            _jwtBuilder = jwtBuilder;
            _oauthHostOptions = options.Value;
        }

        public string Name => TokenResponseParameters.AccessToken;

        public async virtual Task Build(IEnumerable<string> scopes, HandlerContext handlerContext, CancellationToken cancellationToken)
        {
            var jwsPayload = BuildPayload(scopes, handlerContext);
            await SetResponse(handlerContext, jwsPayload, cancellationToken);
        }

        public virtual Task Refresh(JObject previousRequest, HandlerContext currentContext, CancellationToken cancellationToken)
        {
            var scopes = previousRequest.GetScopesFromAuthorizationRequest();
            return Build(scopes, currentContext, cancellationToken);
        }

        protected JwsPayload BuildPayload(IEnumerable<string> scopes, HandlerContext handlerContext)
        {
            var jwsPayload = _grantedTokenHelper.BuildAccessToken(new[]
            {
                handlerContext.Client.ClientId
            }, scopes, handlerContext.Request.IssuerName, handlerContext.Client.TokenExpirationTimeInSeconds);
            if (handlerContext.Client.TokenEndPointAuthMethod == OAuthClientTlsClientAuthenticationHandler.AUTH_METHOD)
            {
                var thumbprint = Hash(handlerContext.Request.Certificate.RawData);
                jwsPayload.Add(SimpleIdServer.Jwt.Constants.OAuthClaims.Cnf, new JObject
                {
                    { SimpleIdServer.Jwt.Constants.OAuthClaims.X5TS256, thumbprint }
                });
            }

            return jwsPayload;
        }

        protected async Task SetResponse(HandlerContext handlerContext, JwsPayload jwsPayload, CancellationToken cancellationToken)
        {
            var authorizationCode = string.Empty;
            if (!handlerContext.Response.TryGet(AuthorizationResponseParameters.Code, out authorizationCode))
            {
                authorizationCode = handlerContext.Request.Data.GetAuthorizationCode();
            }

            var accessToken = await _jwtBuilder.BuildAccessToken(handlerContext.Client, jwsPayload);
            await _grantedTokenHelper.AddAccessToken(accessToken, handlerContext.Client.ClientId, authorizationCode, cancellationToken);
            handlerContext.Response.Add(TokenResponseParameters.AccessToken, accessToken);
        }

        private static string Hash(byte[] payload)
        {
            using (var sha256 = SHA256.Create())
            {
                var hashed = sha256.ComputeHash(payload);
                return Base64UrlTextEncoder.Encode(hashed);
            }
        }
    }
}