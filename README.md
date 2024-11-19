# Azure EventGrid with Private Endpoints and Azure Function Example

This repository provides an example of how Azure EventGrid can work with private endpoints and a private, network-integrated Azure Function by using a storage queue as a relay.

## Prerequisites

- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
- An Azure subscription

## Getting Started

### 1. Create a Resource Group & deploy resources

```bash
# Create a resource group
az group create --name <resource-group-name> --location <location>

# Deploy the Bicep template
az deployment group create \
    --resource-group <resource-group-name> \
    --template-file infra/main.bicep
```

### 2. Upload the function app package

To deploy the `released-package.zip` to the storage container for your private function app, follow these steps:

1. **Prepare the Storage Account**:
   - Locate the container within the storage account where you will upload the package.
   - This will already be created for you an associated to the function app in the bicep template

2. **Upload the Package**:
   - You can use Azure Storage Explorer, Azure CLI, or the Azure Portal to upload the `released-package.zip` to the container.

   **Using Azure CLI**:
   ```sh
   az storage blob upload --account-name <your-storage-account-name> --container-name <your-container-name> --name released-package.zip --file path/to/released-package.zip
   ```
   **Using Azure CLI**:
   ```sh
   az functionapp config appsettings set --name <your-function-app-name> --resource-group <your-resource-group> --settings WEBSITE_RUN_FROM_PACKAGE=https://<your-storage-account-name>.blob.core.windows.net/<your-container-name>/released-package.zip
   ```

3. **Verify Deployment**:
   - Check the function app in the Azure Portal to ensure it is running the new package.
   - Monitor the logs to verify that the deployment was successful.

These steps will help you deploy the `released-package.zip` to your private function app using Azure Storage.

## Documentation

- [Azure EventGrid Documentation](https://docs.microsoft.com/en-us/azure/event-grid/)
- [Azure Functions Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/)
- [Azure Storage Queues Documentation](https://docs.microsoft.com/en-us/azure/storage/queues/)
