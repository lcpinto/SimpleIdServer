﻿// Copyright (c) SimpleIdServer. All rights reserved.
// Licensed under the Apache License, Version 2.0. See LICENSE in the project root for license information.
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using SimpleIdServer.OAuth;
using SimpleIdServer.OAuth.Api;
using SimpleIdServer.OAuth.Exceptions;
using SimpleIdServer.OAuth.Extensions;
using SimpleIdServer.OAuth.Jwt;
using SimpleIdServer.OpenBankingApi.Domains.AccountAccessConsent.Enums;
using SimpleIdServer.OpenBankingApi.Persistences;
using SimpleIdServer.OpenBankingApi.Resources;
using SimpleIdServer.OpenID.Api.Authorization.Validators;
using SimpleIdServer.OpenID.Domains;
using SimpleIdServer.OpenID.DTOs;
using SimpleIdServer.OpenID.Exceptions;
using SimpleIdServer.OpenID.Extensions;
using SimpleIdServer.OpenID.Helpers;
using System;
using System.Linq;
using System.Threading;
using System.Threading.Tasks;

namespace SimpleIdServer.OpenBankingApi.Api.Authorization.Validators
{
    public class OpenBankingApiAuthorizationRequestValidator : OpenIDAuthorizationRequestValidator
    {
        private readonly OpenBankingApiOptions _options;
        private readonly IAccountAccessConsentRepository _accountAccessConsentRepository;
        private readonly ILogger<OpenBankingApiAuthorizationRequestValidator> _logger;

        public OpenBankingApiAuthorizationRequestValidator(
            IOptions<OpenBankingApiOptions> options,
            ILogger<OpenBankingApiAuthorizationRequestValidator> logger,
            IAccountAccessConsentRepository accountAccessConsentRepository,
            IAmrHelper amrHelper, 
            IJwtParser jwtParser) : base(amrHelper, jwtParser)
        {
            _options = options.Value;
            _logger = logger;
            _accountAccessConsentRepository = accountAccessConsentRepository;
        }

        public override async Task Validate(HandlerContext context, CancellationToken cancellationToken)
        {
            var openidClient = (OpenIdClient)context.Client;
            var clientId = context.Request.Data.GetClientIdFromAuthorizationRequest();
            var scopes = context.Request.Data.GetScopesFromAuthorizationRequest();
            var acrValues = context.Request.Data.GetAcrValuesFromAuthorizationRequest();
            var claims = context.Request.Data.GetClaimsFromAuthorizationRequest();
            var prompt = context.Request.Data.GetPromptFromAuthorizationRequest();
            if (!scopes.Any())
            {
                throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(OAuth.ErrorMessages.MISSING_PARAMETER, OAuth.DTOs.AuthorizationRequestParameters.Scope));
            }

            var unsupportedScopes = scopes.Where(s => !context.Client.AllowedScopes.Any(sc => sc.Name == s));
            if (unsupportedScopes.Any())
            {
                throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(OAuth.ErrorMessages.UNSUPPORTED_SCOPES, string.Join(",", unsupportedScopes)));
            }

            if (context.User == null)
            {
                if (prompt == PromptParameters.None)
                {
                    throw new OAuthException(ErrorCodes.LOGIN_REQUIRED, OAuth.ErrorMessages.LOGIN_IS_REQUIRED);
                }

                throw new OAuthLoginRequiredException(await GetFirstAmr(acrValues, claims, openidClient, cancellationToken));
            }

            if (!await CheckRequestParameter(context))
            {
                await CheckRequestUriParameter(context);
            }

            var responseTypes = context.Request.Data.GetResponseTypesFromAuthorizationRequest();
            var nonce = context.Request.Data.GetNonceFromAuthorizationRequest();
            var redirectUri = context.Request.Data.GetRedirectUriFromAuthorizationRequest();
            var maxAge = context.Request.Data.GetMaxAgeFromAuthorizationRequest();
            var idTokenHint = context.Request.Data.GetIdTokenHintFromAuthorizationRequest();
            if (string.IsNullOrWhiteSpace(redirectUri))
            {
                throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(OAuth.ErrorMessages.MISSING_PARAMETER, OAuth.DTOs.AuthorizationRequestParameters.RedirectUri));
            }

            if (responseTypes.Contains(TokenResponseParameters.IdToken) && string.IsNullOrWhiteSpace(nonce))
            {
                throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(OAuth.ErrorMessages.MISSING_PARAMETER, OpenID.DTOs.AuthorizationRequestParameters.Nonce));
            }

            if (maxAge != null)
            {
                if (DateTime.UtcNow > context.User.AuthenticationTime.Value.AddSeconds(maxAge.Value))
                {
                    throw new OAuthLoginRequiredException(await GetFirstAmr(acrValues, claims, openidClient, cancellationToken));
                }
            }
            else if (openidClient.DefaultMaxAge != null && DateTime.UtcNow > context.User.AuthenticationTime.Value.AddSeconds(openidClient.DefaultMaxAge.Value))
            {
                throw new OAuthLoginRequiredException(await GetFirstAmr(acrValues, claims, openidClient, cancellationToken));
            }

            if (!string.IsNullOrWhiteSpace(idTokenHint))
            {
                var payload = await ExtractIdTokenHint(idTokenHint);
                if (context.User.Id != payload.GetSub())
                {
                    throw new OAuthException(ErrorCodes.INVALID_REQUEST, OpenID.ErrorMessages.INVALID_SUBJECT_IDTOKENHINT);
                }

                if (!payload.GetAudiences().Contains(context.Request.IssuerName))
                {
                    throw new OAuthException(ErrorCodes.INVALID_REQUEST, OpenID.ErrorMessages.INVALID_AUDIENCE_IDTOKENHINT);
                }
            }

            switch (prompt)
            {
                case PromptParameters.Login:
                    throw new OAuthLoginRequiredException(await GetFirstAmr(acrValues, claims, openidClient, cancellationToken));
                case PromptParameters.Consent:
                    RedirectToConsentView(context);
                    break;
                case PromptParameters.SelectAccount:
                    throw new OAuthSelectAccountRequiredException();
            }

            if (!context.User.HasOpenIDConsent(clientId, scopes, claims))
            {
                RedirectToConsentView(context);
                return;
            }

            if (claims != null)
            {
                var idtokenClaims = claims.Where(cl => cl.Type == AuthorizationRequestClaimTypes.IdToken && cl.IsEssential && Jwt.Constants.USER_CLAIMS.Contains(cl.Name));
                var invalidClaims = idtokenClaims.Where(icl => !context.User.Claims.Any(cl => cl.Type == icl.Name && (icl.Values == null || !icl.Values.Any() || icl.Values.Contains(cl.Value))));
                if (invalidClaims.Any())
                {
                    throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(SimpleIdServer.OpenID.ErrorMessages.INVALID_CLAIMS, string.Join(",", invalidClaims.Select(i => i.Name))));
                }
            }

            RedirectToConsentView(context, true);
        }

        protected override void RedirectToConsentView(HandlerContext context)
        {
            RedirectToConsentView(context, false);
        }

        private void RedirectToConsentView(HandlerContext context, bool ignoreDefaultRedirection = true)
        {
            var scopes = context.Request.Data.GetScopesFromAuthorizationRequest();
            var claims = context.Request.Data.GetClaimsFromAuthorizationRequest();
            var claim = claims.FirstOrDefault(_ => _.Name == _options.OpenBankingApiConsentClaimName);
            if (claim == null)
            {
                if (ignoreDefaultRedirection)
                {
                    return;
                }

                base.RedirectToConsentView(context);
                return;
            }

            if (scopes.Contains(_options.AccountsScope))
            {
                var consentId = claim.Values.First();
                var accountAccessConsent = _accountAccessConsentRepository.Get(claim.Values.First(), CancellationToken.None).Result;
                if (accountAccessConsent == null)
                {
                    _logger.LogError($"Account Access Consent '{consentId}' doesn't exist");
                    throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(Global.UnknownAccountAccessConsent, consentId));
                }

                if (accountAccessConsent.Status == AccountAccessConsentStatus.AwaitingAuthorisation)
                {
                    throw new OAuthUserConsentRequiredException("OpenBankingApiAccountConsent", "Index");
                }

                if (accountAccessConsent.Status == AccountAccessConsentStatus.Rejected)
                {
                    _logger.LogError($"Account Access Consent '{consentId}' has already been rejected");
                    throw new OAuthException(ErrorCodes.INVALID_REQUEST, Global.AccountAccessConsentRejected);
                }

                if (accountAccessConsent.Status == AccountAccessConsentStatus.Revoked)
                {
                    _logger.LogError($"Account Access Consent '{consentId}' has already been revoked");
                    throw new OAuthException(ErrorCodes.INVALID_REQUEST, Global.AccountAccessConsentRevoked);
                }

                return;
            }

            var s = string.Join(",", scopes);
            _logger.LogError($"consent screen cannot be displayed for the scopes '{s}'");
            throw new OAuthException(ErrorCodes.INVALID_REQUEST, string.Format(Global.ConsentScreenCannotBeDisplayed, s));
        }
    }
}