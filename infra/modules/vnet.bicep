
param name string = 'vnet'
param locaion string = resourceGroup().location

resource vnet 'Microsoft.Network/virtualNetworks@2021-02-01' = {
  name: name
  location: locaion
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: 'default'
        properties: {
          addressPrefix: '10.0.0.0/24'
        }
      }
      {
        name: 'functionapp'
        properties: {
          addressPrefix: '10.0.1.0/24'
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                '*'
              ]
            }
          ]
          delegations: [
            {
              name: 'Microsoft.App/environments'
              properties: {
                serviceName: 'Microsoft.App/environments'
              }
            }
          ]
        }
      }
      {
        name: 'services'
        properties: {
          addressPrefix: '10.0.2.0/24'
          serviceEndpoints: [
            {
              // this service endpoint must be in place to properly secure the Cognitive Services account
              service: 'Microsoft.Storage'
              locations: [
                '*'
              ]
            }
          ]
        }
      }
    ]
  }
}


var subnetIdPrefix = '${vnet.id}/subnets'

output vnetId string = vnet.id
output functionAppSubnetId string = '${subnetIdPrefix}/functionapp'
output servicesSubnetId string = '${subnetIdPrefix}/services'
