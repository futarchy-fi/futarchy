openapi: 3.0.0
info:
  # You application title. Required.
  title: SushiSwap API
  # API version. You can use semantic versioning like 1.0.0,
  # or an arbitrary string like 0.99-beta. Required.
  version: 5.0.0
  
  # API description. Arbitrary text in CommonMark or HTML.
  description: Documentation for interacting with the SushiSwap API
  
  # Link to the page that describes the terms of service.
  # Must be in the URL format.
  # termsOfService: https://www.sushi.com/legal/terms-of-service
  
  # Contact information: name, email, URL.
  contact:
    name: API Support
    # email: support@sushi.com
    url: http://sushi.com/discord
    
# Link to the external documentation (if any).
# Code or documentation generation tools can use description as the text of the link.
# externalDocs:
#   description: Find out more
#   url: https://docs.sushi.com
    
servers:
  - description: Sushi SwapAPI
    url: https://api.sushi.com
  # Added by API Auto Mocking Plugin 
  - description: SwaggerHub API Auto Mocking
    url: https://virtserver.swaggerhub.com/sushi-labs/sushi/5.0.0
tags:
  - name: swap
    description: Returns swap route
  # - name: listDEX
  #   description: Returns the list of supported DEXes
  - name: price
    description: Returns current token price(s)
  - name: token
    description: Returns token data
paths:
  /swap/v5/{chainId}:
    get:
      tags:
        - swap
      summary: generates a route
      operationId: swap
      description: |
        By passing in the appropriate options, you can generate a swap
      parameters:
        - in: path
          name: chainId
          description: chainId
          required: true
          schema:
            type: number
        - in: query
          name: tokenIn
          description: Input token address
          required: true
          schema:
            type: string
        - in: query
          name: tokenOut
          description: Output token address
          required: true
          schema:
            type: string
        - in: query
          name: amount
          description: Input token amount
          required: true
          schema:
            type: integer
            format: int256
            minimum: 1
        - in: query
          name: maxPriceImpact
          description: The max price impact for route planning. It's better to set it to a reasonable value, for example 0.01 (1%)
          required: false
          schema:
            type: number
            minimum: 0
            maximum: 1
            default: 1 (100%)
        - in: query
          name: maxSlippage
          description: The max slippage for route execution
          required: false
          schema:
            type: number
            minimum: 0
            maximum: 1
            default: 0.005
        - in: query
          name: to
          description: The address to send output tokens to. If is not defined, then transaction data is not generated
          required: false
          schema:
            type: string
        - in: query
          name: referrer
          description: Referrer
          required: false
          schema:
            type: string
        - in: query
          name: preferSushi
          description: Prefer Sushi sources of liquidity first
          required: false
          schema:
            type: boolean
            default: false
        - in: query
          name: enableFee
          description: To take the swap fee or not
          required: false
          schema:
            type: boolean
            default: false
        - in: query
          name: feeReceiver
          description: if enableFee=true then receiver of the fee
          required: false
          schema:
            type: string
        - in: query
          name: fee
          description: if enableFee=true then amount of the fee
          required: false
          schema:
            type: number
            minimum: 0
            maximum: 1
            default: 0.0025
        - in: query
          name: feeBy
          description: if enableFee=true then which token to take fee from input or output
          required: false
          schema:
            type: string
            enum: [input, output]
            default: output
        - in: query
          name: includeRouteProcessorParams
          description: if to is defined then includes RouteProcessor params in response
          required: false
          schema:
            type: boolean
            default: false
        - in: query
          name: includeTransaction
          description: if to is defined then includes transaction data in response
          required: false
          schema:
            type: boolean
            default: false
        - in: query
          name: includeRoute
          description: To include route info in response or not
          required: false
          schema:
            type: boolean
            default: false
        - in: query
          name: onlyDEX
          description: A list of DEX names separated by comma. If exists in the request then only pools from these DEXes are used in the response route. List of all supported DEXes can be obtained with /listDEX request
          required: false
          schema:
            type: string
        - in: query
          name: onlyPools
          description: A list of pools addresses separated by comma. If exists in the request then only these pools are used in the response route
          required: false
          schema:
            type: string
      responses:
        '200':
          description: route data
          content:
            application/json:
              schema:
                type: object
                example:
                  status: Success
                  tokens:
                    - address: '0xCc80C051057B774cD75067Dc48f8987C4Eb97A5e'
                      symbol: NEC
                      name: Ethfinex Nectar Token
                      decimals: 18
                    - address: '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2'
                      symbol: WETH
                      name: Wrapped Ether
                      decimals: 18
                    - address: '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2'
                      symbol: SUSHI
                      name: SushiToken
                      decimals: 18
                  tokenFrom: 0
                  tokenTo: 2
                  swapPrice: 0.00727007628361339
                  priceImpact: -0.00465442342625355
                  amountIn: '100000000000000000'
                  assumedAmountOut: '727007628361339'
                  gasSpent: 84000
                  route:
                    - poolAddress: '0x2dda09fB929c576A6AB6c1D1EE62E8AF72b2F6a7'
                      poolType: Classic
                      poolName: UniswapV2 0.3%
                      poolFee: 0.003
                      liquidityProvider: UniswapV2
                      tokenFrom: 0
                      tokenTo: 1
                      share: 1
                      assumedAmountIn: '100000000000000000'
                      assumedAmountOut: '194798139220'
                    - poolAddress: '0xCE84867c3c02B05dc570d0135103d3fB9CC19433'
                      poolType: Classic
                      poolName: UniswapV2 0.3%
                      poolFee: 0.003
                      liquidityProvider: UniswapV2
                      tokenFrom: 1
                      tokenTo: 2
                      share: 1
                      assumedAmountIn: '194798139220'
                      assumedAmountOut: '727007628361339'
                  routeProcessorAddr: '0xf2614A233c7C3e7f08b1F887Ba133a13f1eb2c55'
                  tx:
                    from: '0x32464Be3D71ed9105c142FB6bdEe98a0c649cdd3'
                    to: '0xf2614A233c7C3e7f08b1F887Ba133a13f1eb2c55'
                    data: '0x6678ec1f000000000000000000000000ca226bd9c754f1283123d32b2a7cf62a722f8ada000000000000000000000000000000000000000000000000000001a6c03efad8000000000000000000000000cc80c051057b774cd75067dc48f8987c4eb97a5e000000000000000000000000000000000000000000000000016345785d8a00000000000000000000000000006b3595068778dd592e39a122f4f5a5cf09c90fe20000000000000000000000000000000000000000000000000002948c6267f23100000000000000000000000032464be3d71ed9105c142fb6bdee98a0c649cdd30000000000000000000000000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000008702Cc80C051057B774cD75067Dc48f8987C4Eb97A5e01ffff002dda09fB929c576A6AB6c1D1EE62E8AF72b2F6a700CE84867c3c02B05dc570d0135103d3fB9CC19433000bb804C02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc200CE84867c3c02B05dc570d0135103d3fB9CC1943300f2614A233c7C3e7f08b1F887Ba133a13f1eb2c55000bb800000000000000000000000000000000000000000000000000'
                  
        '422':
          description: request parameters invalid
        '500':
          description: internal server error
  /price/v1/{chainId}:
    get:
      tags:
        - price
      summary: returns prices for specified chainId
      operationId: getPrices
      description: |
        By passing in a chainId, you can get dollar prices for tokens addresses
      parameters:
        - in: path
          name: chainId
          schema:
            type: integer
          required: true
          description: chainId
      responses:
        "200":
          description: A JSON map of address=>usd
          content:
            application/json:
              schema:
                type: object
                additionalProperties:
                  type: number
                example:
                  '0x1': 1337
                  '0x2': 420
                  '0x3': 69
        '422':
          description: request parameters invalid
        '500':
          description: internal server error
  /price/v1/{chainId}/{address}:
    get:
      tags:
        - price
      summary: returns price for specified chainId and token
      operationId: getPrice
      description: |
        By passing in a chainId and address, you can get a dollar price for specified token address
      parameters:
        - in: path
          name: chainId
          schema:
            type: integer
          required: true
          description: chainId
        - in: path
          name: address
          schema:
            type: string
          required: true
          description: token
      responses:
        "200":
          description: A numerical price
          content:
            application/json:
              schema:
                type: number
              example: 1337
        '422':
          description: request parameters invalid
        '500':
          description: internal server error
  /token/v1/{chainId}/{address}:
    get:
      tags:
        - token
      summary: returns token data for specified chainId and token
      operationId: getToken
      description: |
        By passing in a chainId and address, you can get token data for specified token address
      parameters:
        - in: path
          name: chainId
          schema:
            type: integer
          required: true
          description: chainId
        - in: path
          name: address
          schema:
            type: string
          required: true
          description: token
      responses:
        "200":
          description: Token data
          content:
            application/json:
              schema:
                type: object
                additionalProperties:
                  chainId: number
                  address: string
                  decimals: number
                  name: string
                  symbol: string
                example:
                  chainId: 1
                  address: '0x6B3595068778DD592e39A122f4f5a5cF09C90fE2'
                  decimals: 18
                  name: 'Sushi Token'
                  symbol: 'SUSHI'
        '422':
          description: request parameters invalid
        '500':
          description: internal server error
  /liquidity-providers/v5/{chainId}:
    get:
      tags:
        - liquidity-provider
      summary: Returns all available liquidity providers for the specified chainId
      operationId: getLiquidityProviders
      description: |
        By passing in a chainId you can get the enabled liquidity providers.
      parameters:
        - in: path
          name: chainId
          schema:
            type: integer
          required: true
          description: The chain identifier.
      responses:
        "200":
          description: Liquidity Provider data
          content:
            application/json:
              schema:
                type: array
                items:
                  type: string
                example:
                  - "UniswapV2"
                  - "SushiSwapV2"
                  - "PancakeSwap"
                  - "Elk"
                  - "Kwikswap"
                  - "ShibaSwap"
                  - "CroDefiSwap"
                  - "UniswapV3"
                  - "SushiSwapV3"
                  - "PancakeSwapV3"
                  - "Wagmi"
                  - "CurveSwap"
        "422":
          description: Request parameters invalid.
        "500":
          description: Internal server error.
