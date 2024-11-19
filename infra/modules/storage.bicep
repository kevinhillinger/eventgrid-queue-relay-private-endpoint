param name string = 'eventsrc0${substring(uniqueString(resourceGroup().id), 0, 6)}'
param location string = resourceGroup().location

// the storage account that event grid will trigger events from (the event source)

resource account 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  identity: {
    type: 'None'
  }
  properties: {
    defaultToOAuthAuthentication: false
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      bypass: 'AzureServices'
      virtualNetworkRules: []
      ipRules: []
      defaultAction: 'Allow'
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource service 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  parent: account
  name: 'default'
}

resource eventSource 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: service
  name: 'event-source'
  properties: {
    publicAccess: 'None'
  }

}

output storageAccountName string = account.name
