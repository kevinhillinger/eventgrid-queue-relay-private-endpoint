param systemTopicName string = 'eventgrid-systemtopic'
param location string = resourceGroup().location
param eventSourceStorageAccountName string

param virtualNetwork object = {
  id: null
  subnetId: null
  location: null
}

@description('the storage account that the event grid will use for dead lettering and the queue for a relay for the function app')
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: 'egstor0${substring(uniqueString(resourceGroup().id), 0, 6)}'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    allowBlobPublicAccess: false
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2022-05-01' = {
  parent: storageAccount
  name: 'default'
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2021-04-01' = {
  parent: storageAccount
  name: 'default'
}

resource deadLetterContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  parent: blobService
  name: 'dead-letters'
}

@description('This is the queue that the function app will use to get events from the system topic.')
var queueName = 'events'
resource queue 'Microsoft.Storage/storageAccounts/queueServices/queues@2021-04-01' = {
  parent: queueService
  name: queueName
}


// because private endpoint is being used by the function app, we need to use the system topic with a system assigned identity
// to allow the function app to access the system topic through Azure storage queue.
// see: https://learn.microsoft.com/en-us/azure/event-grid/consume-private-endpoints#deliver-events-to-storage-using-managed-identity

resource systemTopic 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' = {
  name: systemTopicName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    source: resourceId('Microsoft.Storage/storageAccounts', eventSourceStorageAccountName)
    topicType: 'Microsoft.Storage.StorageAccounts'
  }
}


// ---------------------


@description('This is the built-in sender role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage')
resource storageQueueDataMessageSenderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'c6a89b2d-59bc-44d0-9896-0f6e12d7b80a'
}

@description('This is the built-in Storage Blob Data Contributor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage')
resource storageBlobDataContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
}


var definitions = [storageQueueDataMessageSenderRoleDefinition.name, storageBlobDataContributorRoleDefinition.name]

resource roleAssignments 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for name in definitions: {
  name: guid(resourceGroup().id, storageAccount.id, name)
  scope: storageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', name)
    principalId: systemTopic.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]

resource subscription 'Microsoft.EventGrid/systemTopics/eventSubscriptions@2024-06-01-preview' = {
  parent: systemTopic
  name: 'storageevents-subscription'
  properties: {
    deliveryWithResourceIdentity: {
      identity: {
        type: 'SystemAssigned'
      }
      destination: {
        properties: {
          resourceId: storageAccount.id
          queueName: queueName
          queueMessageTimeToLiveInSeconds: 604800
        }
        endpointType: 'StorageQueue'
      }
    }
    filter: {
      includedEventTypes: [
        'Microsoft.Storage.BlobCreated'
        'Microsoft.Storage.BlobDeleted'
      ]
      enableAdvancedFilteringOnArrays: true
    }
    labels: []
    eventDeliverySchema: 'EventGridSchema'
    retryPolicy: {
      maxDeliveryAttempts: 4
      eventTimeToLiveInMinutes: 1440
    }
    deadLetterWithResourceIdentity: {
      identity: {
        type: 'SystemAssigned'
      }
      deadLetterDestination: {
        properties: {
          resourceId: storageAccount.id
          blobContainerName: deadLetterContainer.name
        }
        endpointType: 'StorageBlob'
      }
    }
  }
  dependsOn: [privateEndpoint, roleAssignments]
}

// private endpoint for queue storage

module privateEndpoint 'network/privateendpoint.bicep' = {
  name: 'eventGridStoragePrivateEndpoint'
  params: {
    name: 'pe-${storageAccount.name}'
    location: virtualNetwork.location
    privateDnsZoneName: 'privatelink.queue.core.windows.net'
    privateLinkServiceId: storageAccount.id
    groupId: 'queue'
    virtualNetworkId: virtualNetwork.id
    subnetId: virtualNetwork.subnetId
  }
}


output queueStorageAccountName string = storageAccount.name
