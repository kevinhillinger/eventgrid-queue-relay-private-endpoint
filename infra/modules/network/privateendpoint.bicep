@description('The name of the private endpoint')
param name string
param location string
param virtualNetworkId string
param subnetId string

@allowed([
  'account'
  'sites'
  'queue'
  'redisCache'
  'vault'
  'searchService'
])
param groupId string
param privateLinkServiceId string


@allowed([
  'privatelink.queue.core.windows.net'
  'privatelink.redis.cache.windows.net'
  'privatelink.cognitiveservices.azure.com'
  'privatelink.openai.azure.com'
  'privatelink.search.windows.net'
  'privatelink.azurewebsites.net'
  'privatelink.vault.azure.net'
])
param privateDnsZoneName string

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2022-01-01' = {
  name: name
  location: location
  properties: {
    customNetworkInterfaceName: '${name}-nic'
    privateLinkServiceConnections: [
      {
        name: name
        properties: {
          groupIds: [groupId]
          privateLinkServiceId: privateLinkServiceId
        }
      }
    ]
    subnet: {
      id: subnetId
    }
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: privateDnsZoneName
  location: 'global'
}

resource privateEndpointDns 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2022-01-01' = {
  parent: privateEndpoint
  name: 'openai-PrivateDnsZoneGroup'
  properties:{
    privateDnsZoneConfigs: [
      {
        name: privateDnsZoneName
        properties:{
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}

resource privateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: privateDnsZone
  name: uniqueString(privateLinkServiceId)
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: virtualNetworkId
    }
  }
}
