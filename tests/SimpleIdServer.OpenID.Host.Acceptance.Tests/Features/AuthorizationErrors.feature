﻿Feature: AuthorizationErrors
	Check the errors returned by the authorization endpoint

Scenario: Error is returned when scope is missing
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	

	And extract JSON from body
	And extract parameter 'client_id' from JSON body

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|

	And extract JSON from body

	Then HTTP status code equals to '400'
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='missing parameter scope'

Scenario: Error is returned when openid scope is missing	
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	

	And extract JSON from body
	And extract parameter 'client_id' from JSON body

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|
	| scope			| scope1										|
	
	And extract JSON from body

	Then HTTP status code equals to '400'
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='openid scope is missing'

Scenario: Error is returned when the scope is not supported by the client
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	

	And extract JSON from body
	And extract parameter 'client_id' from JSON body

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|
	| scope			| openid role									|
	
	And extract JSON from body

	Then HTTP status code equals to '400'
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='scopes role are not supported'

Scenario: Error is returned when redirect_uri is missing		
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	

	And extract JSON from body
	And extract parameter 'client_id' from JSON body

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|
	| scope			| openid										|
	
	And extract JSON from body
	
	Then HTTP status code equals to '400'
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='missing parameter redirect_uri'

Scenario: Error is returned when id_token_hint is not present and prompt=none
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	

	And extract JSON from body
	And extract parameter 'client_id' from JSON body

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|
	| scope			| openid										|
	| redirect_uri	| https://web.com								|
	| prompt		| none											|

	And extract JSON from body

	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='missing parameter id_token_hint'

Scenario: Error is returned when subject in the id_token_hint is not correct
	When add JSON web key to Authorization Server and store into 'jwks'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |
	
	And use '1' JWK from 'jwks' to build JWS and store into 'id_token_hint'
	| Key           | Value         |
	| sub           | otheruser     |
	
	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	

	And extract JSON from body
	And extract parameter 'client_id' from JSON body 

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|
	| scope			| openid										|
	| redirect_uri	| https://web.com								|
	| prompt		| none											| 
	| id_token_hint | $id_token_hint$								|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='subject contained in id_token_hint is invalid'

Scenario: Error is returned when audience in the id_token_hint is not correct
	When add JSON web key to Authorization Server and store into 'jwks'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |
	
	And use '1' JWK from 'jwks' to build JWS and store into 'id_token_hint'
	| Key           | Value         |
	| sub           | administrator |
	| aud           | aud1 aud2     |
	
	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	

	And execute HTTP GET request 'http://localhost/authorization'
	| Key			| Value											|
	| response_type | code											|
	| client_id		| $client_id$									|
	| state			| state											|
	| response_mode	| query											|
	| scope			| openid										|
	| redirect_uri	| https://web.com								|
	| prompt		| none											| 
	| id_token_hint | $id_token_hint$								|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='audience contained in id_token_hint is invalid'

Scenario: Error is returned when the value specified in claims parameter is invalid
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	And add user consent with claim : user='administrator', scope='email', clientId='$client_id$', claim='sub=administrator'	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value															|
	| response_type		| code															|
	| client_id			| $client_id$													|
	| state				| state															|
	| response_mode		| query															|
	| scope				| openid email													|
	| redirect_uri		| https://web.com												|
	| claims			| { id_token: { sub: { essential : true, value: "invalid" } } }	|

	And extract JSON from body

	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='claims sub are invalid'
		
Scenario: Error is returned when request parameter is not a valid JWT token
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |	
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| invalid																					|
	| state				| state																						|

	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='request parameter is invalid'

Scenario: Error is returned when request parameter is not a valid JWS token
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| a.b.c																						|
	| state				| state																						|

	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='request parameter is not a valid JWS token'

Scenario: Error is returned when request parameter is a JWS token with an invalid algorithm name
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS384   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| key           | val		    |	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the signature algorithm is invalid'
	
Scenario: Error is returned when request parameter doesn't contain issuer
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| key           | val		    |	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|

	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the issuer claim is missing'

Scenario: Error is returned when request parameter contains an invalid issuer
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| iss           | invalid	    |	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the issuer claim is invalid'

Scenario: Error is returned when request parameter doesn't contain audience
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| iss           | $client_id$   |	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the audience claim is missing'

Scenario: Error is returned when request parameter doesn't contain response_type
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| iss           | $client_id$   |	
	| aud			| aud1			|
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the response type claim is missing'

Scenario: Error is returned when request parameter doesn't contain client_id
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| iss           | $client_id$   |	
	| aud			| aud1			|
	| response_type | code			|
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the client identifier claim is missing'

Scenario: Error is returned when request parameter contains an invalid response_type
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| iss           | $client_id$   |	
	| aud			| aud1			|
	| response_type | token			|
	| client_id		| $client_id$	|
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the response type claim is invalid'

Scenario: Error is returned when request parameter contains an invalid client identifier
	When build JSON Web Keys, store JWKS into 'jwks' and store the public keys into 'jwks_json'
	| Type | Kid | AlgName |
	| SIG  | 1   | RS256   |

	And execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	| request_object_signing_alg   | RS256			   |
	| jwks						   | $jwks_json$	   |
	| client_id					   | invalid		   |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And use '1' JWK from 'jwks' to build JWS and store into 'request'
	| Key           | Value         |
	| iss           | $client_id$   |	
	| aud			| aud1			|
	| response_type | code			|
	| client_id		| invalid		|
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value																						|
	| response_type		| code																						|
	| client_id			| $client_id$																				|
	| scope				| openid																					|
	| request			| $request$																					|
	| state				| state																						|
	
	And extract JSON from body
	
	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='the client identifier claim is invalid'

Scenario: Error is returned when request uri is invalid
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value			|
	| response_type		| code			|
	| client_id			| $client_id$	|
	| scope				| openid		|
	| state				| state			|
	| request_uri		| uri			|

	And extract JSON from body

	Then JSON 'error'='invalid_request'
	Then JSON 'error_description'='request uri parameter is invalid'

Scenario: Redirect to the login page when prompt=login
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value							|
	| response_type		| code							|
	| client_id			| $client_id$					|
	| state				| state							|
	| response_mode		| query							|
	| scope				| openid						|
	| redirect_uri		| https://web.com				|
	| prompt			| login							|

	And extract JSON from body
	
	Then redirect url contains 'http://localhost/Authenticate'

Scenario: Redirect to the account page when prompt=select_account
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body	
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value							|
	| response_type		| code							|
	| client_id			| $client_id$					|
	| state				| state							|
	| response_mode		| query							|
	| scope				| email openid					|
	| redirect_uri		| https://web.com				|
	| prompt			| select_account				|
	
	And extract JSON from body
	
	Then redirect url contains 'http://localhost/Account'


Scenario: Redirect to the consents page when no consent has been given for the specific claim
	When execute HTTP POST JSON request 'http://localhost/register'
	| Key                          | Value             |
	| redirect_uris                | [https://web.com] |
	| scope                        | email             |
	
	And extract JSON from body
	And extract parameter 'client_id' from JSON body
	And add user consent : user='administrator', scope='email', clientId='$client_id$'
	
	And execute HTTP GET request 'http://localhost/authorization'
	| Key				| Value												|
	| response_type		| code												|
	| client_id			| $client_id$										|
	| state				| state												|
	| response_mode		| query												|
	| scope				| openid email										|
	| redirect_uri		| https://web.com									|
	| claims			| { id_token: { name: { essential : true } } }		|
	
	And extract JSON from body
	
	Then redirect url contains 'http://localhost/Consents'