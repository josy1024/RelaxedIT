# Az.Storage. AzTable

# Define variables
$resourceGroupName = "WE-josy1024-Nutzungsbasiert-Standard"
$storageAccountName = "endpointlogger"
$tableName = "MyNewTable"
$partitionKey = "Partition1"
$rowKey = "Row1"
$property1 = "Value1"
$property2 = "Value2"

# Create a storage context
$storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
$storageContext = $storageAccount.Context

# Create a new table if it doesn't exist
$table = New-AzStorageTable -Name $tableName -Context $storageContext

# Create a new entity
$entity = New-Object -TypeName PSObject -Property @{
    PartitionKey = $partitionKey
    RowKey = $rowKey
    Property1 = $property1
    Property2 = $property2
}

$entity = New-Object -TypeName PSObject -Property @{
    Property1 = $property1
    Property2 = $property2
}

$entity = @{
    PartitionKey = "partition1"
    RowKey = "1"
    username = "JohnDoe"
    userid = 1
}

$table = (Get-AzStorageTable -Name $tableName -Context $storageContext).CloudTable
 
# Insert the entity into the table
$entity | Add-AzTableRow -Table $table

$prop = @{
    computername = "nbxxx"
    userid = 23
	task = "eventx"
}

Add-AzTableRow -Table $table -PartitionKey "sw" -RowKey 3 -property $prop


# Step 1: Retrieve the entity
$entity = Get-AzTableRow -table $table -customFilter "(PartitionKey eq 'sw') and (RowKey eq '4')"      
# Step 2: Modify the entity
$entity.task = 'Jessie2'

# Step 3: Update the entity
Update-AzTableRow -table $table -entity $entity


Write-Host "Entity inserted successfully into the table."


$entity = @{
    PartitionKey = "Partition1"
    RowKey = "Row1"
    Property1 = "Value1"
    Property2 = "Value2"
}
Add-AzTableRow -TableName $table -Entity $entity -Context $storageContext


Connect-AzAccount  
Set-AzContext -Subscription "<your subscription name>"  
$storageAccountName ="<your storage account name>"  
$resourceGroup = "<your resource group name>"  
$storageAccount=Get-AzStorageAccount -ResourceGroupName $resourceGroup -Name $storageAccountName  
$ctx = $storageAccount.Context  
$tableName = "TableName"  
$cloudTable = (Get-AzStorageTable –Name $tableName –Context $ctx).CloudTable  
Add-AzTableRow -table $cloudTable -partitionKey "PK2" -rowKey ("CA") -property @{"username"="Chris";"userid"=1} 