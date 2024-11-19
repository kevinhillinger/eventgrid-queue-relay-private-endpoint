
module vnet './modules/vnet.bicep' = {
  name: 'vnet'
}

module storage './modules/storage.bicep' = {
  name: 'storage'
  params: {
  }
  dependsOn: [
    vnet
  ]
}

module eventGrid './modules/eventgrid.bicep' = {
  name: 'eventGrid'
  params: {
    eventSourceStorageAccountName: storage.outputs.storageAccountName
    virtualNetwork: {
      id: vnet.outputs.vnetId
      subnetId: vnet.outputs.servicesSubnetId
      location: resourceGroup().location
    }
  }
  dependsOn: [
    storage
  ]
}

module functionApp './modules/functionapp.bicep' = {
  name: 'functionApp'
  params: {
    virtualNetwork: {
      id: vnet.outputs.vnetId
      integrationSubnetId: vnet.outputs.functionAppSubnetId
      privateEndpointSubnetId: vnet.outputs.servicesSubnetId
    }
    queueStorageAccountName: eventGrid.outputs.queueStorageAccountName
  }
  dependsOn: [
    vnet
    eventGrid
  ]
}
