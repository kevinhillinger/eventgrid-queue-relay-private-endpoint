param functionAppName string = 'queuetrigger-fn-${substring(uniqueString(resourceGroup().id), 0, 6)}'
param location string = resourceGroup().location

param virtualNetwork object = {
  id: null
  integrationSubnetId: null
  privateEndpointSubnetId: null
}

param queueStorageAccountName string

var hostingPlanName = functionAppName
var storageAccountName = 'taaifn0${substring(uniqueString(resourceGroup().id, functionAppName), 0, 6)}'
var applicationInsightsName = functionAppName

// application insights
module applicationInsights 'monitor/applicationinsights.bicep' = {
  name: 'applicationInsights'
  params: {
    name: applicationInsightsName
  }
}


// Generate a unique token to be used in naming resources, then Generate a unique container name that will be used for deployments.
// this will be used only for flex consumption configuration
var resourceToken = toLower(uniqueString(subscription().id, resourceGroup().id, location))
var deploymentStorageContainerName = 'app-package-${take(functionAppName, 32)}-${take(resourceToken, 7)}'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'Storage'
  properties: {
    supportsHttpsTrafficOnly: true
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
  }

  resource blobServices 'blobServices' = {
    name: 'default'
    properties: {
      deleteRetentionPolicy: {}
    }
    resource container 'containers' = {
      name: deploymentStorageContainerName
      properties: {
        publicAccess: 'None'
      }
    }
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2023-12-01' = {
  name: hostingPlanName
  location: location
  sku: {
    name: 'FC1'
    tier: 'FlexConsumption'
  }
  kind: 'functionapp'
  properties: {
    reserved: true
  }
}

resource functionApp 'Microsoft.Web/sites@2023-12-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    reserved: true
    vnetRouteAllEnabled: true
    virtualNetworkSubnetId: virtualNetwork.integrationSubnetId
    functionAppConfig: {
      deployment: {
        storage: {
          type: 'blobContainer'
          value: '${storageAccount.properties.primaryEndpoints.blob}${deploymentStorageContainerName}'
          authentication: {
            type: 'SystemAssignedIdentity'
          }
        }
      }
      runtime: {
        name: 'python'
        version: '3.11'
      }
      scaleAndConcurrency: {
        maximumInstanceCount: 100
        instanceMemoryMB: 4096
      }
    }
    siteConfig: {
      // Only required for Linux app to represent runtime stack in the format of \'runtime|runtimeVersion\'. For example: \'python|3.9\
      vnetRouteAllEnabled: true
      appSettings: [
        // this setting instructs the host to use the identity instead of searching for a stored secret
        // see: https://learn.microsoft.com/en-us/azure/azure-functions/functions-identity-based-connections-tutorial#edit-the-azurewebjobsstorage-configuration
        {
          name: 'AzureWebJobsStorage__accountName'
          value: storageAccount.name
        }

        // this setting is a built in setting that tells the function app to use the managed identity
        // to access the queue service instead of using a connection string. This is the recommended way.
        // Set the trigger connection argument to "QueueConnection"
        {
          name: 'QueueConection__queueServiceUri'
          value: 'https://${queueStorageAccountName}.queue.core.windows.net/'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: applicationInsights.outputs.applicationInsightsConnectionString
        }
      ]
    }
    httpsOnly: true
  }
  dependsOn: [
    applicationInsights
  ]
}

// ------------------------------------------
// storage role assignment

var storageRoleDefinitionId  = 'b7e6dc6d-f1e8-4753-8033-0f276bb0955b' //Storage Blob Data Owner role

// Allow access from function app to storage account using a managed identity
resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: guid(storageAccount.id, storageRoleDefinitionId)
  scope: storageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', storageRoleDefinitionId)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}

// ------------------------------------------

resource queueStorageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: queueStorageAccountName
}

// ------------------------------------------
// storage queue role assignments

// assign the correct roles to the system assigned identity
@description('This is the built-in Storage Queue Data Message Processor role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage')
resource storageQueueDataMessageProcessorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '8a0f0c08-91a1-4084-bc3d-661d67233fed'
}

@description('This is the built-in Storage Queue Data Reader role. See https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles/storage')
resource storageQueueDataReaderRoleDefinition 'Microsoft.Authorization/roleDefinitions@2022-04-01' existing = {
  scope: resourceGroup()
  name: '19e7f393-937e-4f77-808e-94535e297925'
}

var storageQueueRoles = [
  storageQueueDataMessageProcessorRoleDefinition.name
  storageQueueDataReaderRoleDefinition.name
]

resource roleAssignmentsForStorageQueue 'Microsoft.Authorization/roleAssignments@2022-04-01' = [for name in storageQueueRoles: {
  name: guid(resourceGroup().id, queueStorageAccount.id, name)
  scope: queueStorageAccount
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', name)
    principalId: functionApp.identity.principalId
    principalType: 'ServicePrincipal'
  }
}]


// private endpoint wireup
module privateEndpoint './network/privateendpoint.bicep' = {
  name: 'functionAppPrivateEndpoint'
  params: {
    name: 'pe-${functionAppName}'
    location: location
    groupId: 'sites'
    privateLinkServiceId: functionApp.id
    privateDnsZoneName: 'privatelink.azurewebsites.net'
    subnetId: virtualNetwork.privateEndpointSubnetId
    virtualNetworkId: virtualNetwork.id
  }
}

output functionAppName string = functionApp.name
