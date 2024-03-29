#Requires -Version 7
#Requires -Modules Pester

BeforeAll {
    $testOutParams = @{
        FilePath = (New-Item "TestDrive:/Test.json" -ItemType File).FullName
        Encoding = 'utf8'
    }

    $testScript = $PSCommandPath.Replace('.Tests.ps1', '.ps1')
    $testParams = @{
        ScriptName  = 'Test (Brecht)'
        ImportFile  = $testOutParams.FilePath
        LogFolder   = New-Item 'TestDrive:/log' -ItemType Directory
        ScriptAdmin = 'admin@contoso.com'
    }

    Mock Send-MgUserMail
    Mock Send-MailHC
    Mock Write-EventLog
}
Describe 'the mandatory parameters are' {
    It '<_>' -ForEach @('ImportFile', 'ScriptName') {
        (Get-Command $testScript).Parameters[$_].Attributes.Mandatory |
        Should -BeTrue
    }
}
Describe 'send an e-mail to the admin when' {
    BeforeAll {
        $MailAdminParams = {
            ($To -eq $testParams.ScriptAdmin) -and ($Priority -eq 'High') -and
            ($Subject -eq 'FAILURE')
        }
    }
    It 'the log folder cannot be created' {
        $testNewParams = $testParams.clone()
        $testNewParams.LogFolder = 'xxx:://notExistingLocation'

        .$testScript @testNewParams

        Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
            (&$MailAdminParams) -and
            ($Message -like '*Failed creating the log folder*')
        }
    }
    Context 'the ImportFile' {
        It 'is not found' {
            $testNewParams = $testParams.clone()
            $testNewParams.ImportFile = 'nonExisting.json'

            .$testScript @testNewParams

            Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                    (&$MailAdminParams) -and ($Message -like "Cannot find path*nonExisting.json*")
            }
            Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                $EntryType -eq 'Error'
            }
        }
        Context 'property' {
            It 'MailFrom is missing' {
                @{
                    Suppliers = @(
                        @{
                            Name     = 'Picard'
                            Path     = 'TestDrive:/'
                            MailFrom = 'bob@contoso.com'
                        }
                    )
                } | ConvertTo-Json | Out-File @testOutParams

                .$testScript @testParams

                Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                    (&$MailAdminParams) -and ($Message -like "*$ImportFile*No 'MailFrom' addresses found*")
                }
                Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                    $EntryType -eq 'Error'
                }
            }
            It 'Suppliers is missing' {
                @{
                    MailFrom = @('bob@contoso.com')
                } | ConvertTo-Json | Out-File @testOutParams

                .$testScript @testParams

                Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                    (&$MailAdminParams) -and ($Message -like "*$ImportFile*No 'Suppliers' found*")
                }
                Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                    $EntryType -eq 'Error'
                }
            }
            Context 'Property Suppliers' {
                It 'Path is missing' {
                    @{
                        MailFrom  = @('bob@contoso.com')
                        Suppliers = @(
                            @{
                                Name          = 'Picard'
                                # Path   = 'TestDrive:/'
                                MailTo        = 'bob@contoso.com'
                                NewerThanDays = 0
                            }
                        )
                    } | ConvertTo-Json | Out-File @testOutParams

                    .$testScript @testParams

                    Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                        (&$MailAdminParams) -and ($Message -like "*$ImportFile*Property 'Path' is missing in 'Suppliers'*")
                    }
                    Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                        $EntryType -eq 'Error'
                    }
                }
                It 'Path does not exist' {
                    @{
                        MailFrom  = @('bob@contoso.com')
                        Suppliers = @(
                            @{
                                Name          = 'Picard'
                                Path          = 'C:/notExisting'
                                MailTo        = 'bob@contoso.com'
                                NewerThanDays = 0
                            }
                        )
                    } | ConvertTo-Json | Out-File @testOutParams

                    .$testScript @testParams

                    Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                        (&$MailAdminParams) -and ($Message -like "*$ImportFile*'Path' folder 'C:/notExisting' not found*")
                    }
                    Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                        $EntryType -eq 'Error'
                    }
                }
                It 'Name is missing' {
                    @{
                        MailFrom  = @('bob@contoso.com')
                        Suppliers = @(
                            @{
                                # Name   = 'Picard'
                                Path          = 'TestDrive:/'
                                MailTo        = 'bob@contoso.com'
                                NewerThanDays = 0
                            }
                        )
                    } | ConvertTo-Json | Out-File @testOutParams

                    .$testScript @testParams

                    Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                        (&$MailAdminParams) -and ($Message -like "*$ImportFile*Property 'Name' is missing in 'Suppliers'*")
                    }
                    Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                        $EntryType -eq 'Error'
                    }
                }
                It 'MailTo is missing' {
                    @{
                        MailFrom  = @('bob@contoso.com')
                        Suppliers = @(
                            @{
                                Name          = 'Picard'
                                Path          = 'TestDrive:/'
                                # MailTo = 'bob@contoso.com'
                                NewerThanDays = 0
                            }
                        )
                    } | ConvertTo-Json | Out-File @testOutParams

                    .$testScript @testParams

                    Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                        (&$MailAdminParams) -and ($Message -like "*$ImportFile*Property 'MailTo' is missing in 'Suppliers'*")
                    }
                    Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                        $EntryType -eq 'Error'
                    }
                }
                It 'NewerThanDays is missing' {
                    @{
                        MailFrom  = @('bob@contoso.com')
                        Suppliers = @(
                            @{
                                Name   = 'Picard'
                                Path   = 'TestDrive:/'
                                MailTo = 'bob@contoso.com'
                                # NewerThanDays = 0
                            }
                        )
                    } | ConvertTo-Json | Out-File @testOutParams

                    .$testScript @testParams

                    Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                        (&$MailAdminParams) -and ($Message -like "*$ImportFile*Property 'NewerThanDays' is missing*")
                    }
                    Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                        $EntryType -eq 'Error'
                    }
                }
                It 'NewerThanDays is not a number' {
                    @{
                        MailFrom  = @('bob@contoso.com')
                        Suppliers = @(
                            @{
                                Name          = 'Picard'
                                Path          = 'TestDrive:/'
                                MailTo        = 'bob@contoso.com'
                                NewerThanDays = 'a'
                            }
                        )
                    } | ConvertTo-Json | Out-File @testOutParams

                    .$testScript @testParams

                    Should -Invoke Send-MailHC -Exactly 1 -ParameterFilter {
                        (&$MailAdminParams) -and ($Message -like "*$ImportFile*'NewerThanDays' needs to be a number, the value 'a' is not supported. Use number '0' to only handle files with creation date today.*")
                    }
                    Should -Invoke Write-EventLog -Exactly 1 -ParameterFilter {
                        $EntryType -eq 'Error'
                    }
                }
            }
        }
    }
}
Describe 'when all tests pass' {
    BeforeAll {
        $testAscFile = @"
BE1021058802552104737363                    0022016630Faber W Krommenie                  Rosariumlaan 47                    KROMMENI                           000000000000103464CEM I 42,5 N BULK                       29.700202203142022031507150092BJT9              CNLSS128
NL1121058805192104737268                    0021700679MEBIN Tessel DENBOSCH              Tesselschadestraat 30              's-Hertogenbosch                   000000000000103415CEM III/B 42,5 N LH NCR BULK            37.7802022031520220315060000DUMSIMONS01         C
"@

        $testExportedExcelRows = @(
            @{
                Plant               = 'BE10'
                ShipmentNumber      = 2105880255
                DeliveryNumber      = 2104737363
                ShipToNumber        = 22016630
                ShipToName          = 'Faber W Krommenie'
                Address             = 'Rosariumlaan 47'
                City                = 'KROMMENI'
                MaterialNumber      = 103464
                MaterialDescription = 'CEM I 42,5 N BULK'
                Tonnage             = 29.700
                LoadingDate         = Get-Date('3/14/2022')
                DeliveryDate        = Get-Date('3/15/2022 7:15:00 AM')
                TruckID             = '92BJT9'
                PickingStatus       = 'C'
                SiloBulkID          = 'NLSS128'
                File                = 'Test1'
            }
            @{
                Plant               = 'NL11'
                ShipmentNumber      = 2105880519
                DeliveryNumber      = 2104737268
                ShipToNumber        = 21700679
                ShipToName          = 'MEBIN Tessel DENBOSCH'
                Address             = 'Tesselschadestraat 30'
                City                = "'s-Hertogenbosch"
                MaterialNumber      = 103415
                MaterialDescription = 'CEM III/B 42,5 N LH NCR BULK'
                Tonnage             = 37.780
                LoadingDate         = Get-Date('3/15/2022')
                DeliveryDate        = Get-Date('3/15/2022 6:00:00 AM')
                TruckID             = 'DUMSIMONS01'
                PickingStatus       = 'C'
                SiloBulkID          = ''
                File                = 'Test1'
            }
        )

        $testAscFileOutParams = @{
            FilePath = (New-Item "TestDrive:/Test1.asc" -ItemType File).FullName
            Encoding = 'utf8'
        }
        $testAscFile | Out-File @testAscFileOutParams

        @{
            MailFrom  = 'boss@contoso.com'
            Suppliers = @(
                @{
                    Name          = 'Picard'
                    Path          = 'TestDrive:/'
                    MailTo        = 'bob@contoso.com'
                    MailBcc       = @('jack@contoso.com', 'mike@contoso.com')
                    NewerThanDays = 5
                }
            )
        } | ConvertTo-Json -Depth 5 | Out-File @testOutParams

        $testMail = @{
            From           = 'boss@contoso.com'
            To             = 'bob@contoso.com'
            Bcc            = @('jack@contoso.com', 'mike@contoso.com')
            SentItemsPath  = '\PowerShell\{0} SENT' -f $testParams.ScriptName
            EventLogSource = $testParams.ScriptName
            Subject        = 'Picard, 2 deliveries'
            Body           = "<p>Dear supplier</p><p>Since delivery date <b>15/03/2022</b> there have been <b>2 deliveries</b>.</p><p><i>* Check the attachment for details</i></p>*"
        }

        .$testScript @testParams
    }
    Context 'export an Excel file' {
        BeforeAll {
            $testExcelLogFile = Get-ChildItem $testParams.LogFolder -File -Recurse -Filter '* - Picard - Summary.xlsx'

            $actual = Import-Excel -Path $testExcelLogFile.FullName -WorksheetName 'Data'
        }
        It 'to the log folder' {
            $testExcelLogFile | Should -Not -BeNullOrEmpty
        }
        It 'with the correct total rows' {
            $actual | Should -HaveCount $testExportedExcelRows.Count
        }
        It 'with the correct data in the rows' {
            foreach ($testRow in $testExportedExcelRows) {
                $actualRow = $actual | Where-Object {
                    $_.ShipmentNumber -eq $testRow.ShipmentNumber
                }
                @(
                    'Plant', 'DeliveryNumber', 'ShipToNumber', 'ShipToName',
                    'Address', 'City', 'MaterialNumber', 'MaterialDescription',
                    'Tonnage', 'LoadingDate', 'TruckID', 'PickingStatus',
                    'SiloBulkID', 'File'
                ) | ForEach-Object {
                    $actualRow.$_ | Should -Be $testRow.$_
                }
            }
        }
    }
    It 'copy the .ASC files to the log folder' {
        Get-ChildItem $testParams.LogFolder -File -Recurse -Filter '* - Picard - Test1.asc' | Should -Not -BeNullOrEmpty
    }
    It 'send a summary mail to the user' {
        Should -Invoke Send-MgUserMail -Exactly 1 -Scope Describe -ParameterFilter {
            ($UserId -eq $testMail.From) -and
            ($BodyParameter.SaveToSentItems -eq $false) -and
            ($BodyParameter.Message.ToRecipients.EmailAddress.Address -eq $testMail.To) -and
            ($BodyParameter.Message.BccRecipients[0].EmailAddress.Address -eq $testMail.Bcc[0]) -and
            ($BodyParameter.Message.BccRecipients[1].EmailAddress.Address -eq $testMail.Bcc[1]) -and
            ($BodyParameter.Message.Subject -eq $testMail.Subject) -and
            ($BodyParameter.Message.Attachments.Name -like '* - Picard - Summary.xlsx') -and
            ($BodyParameter.Message.Attachments.Count -eq 1) -and
            # ($BodyParameter.Message.Attachments[0].ContentBytes) -and
            # ($BodyParameter.Message.Attachments.'@odata.type' -eq '#microsoft.graph.fileAttachment') -and
            ($BodyParameter.Message.Body.Content -like $testMail.Body)
        }
    }
}