--:BEGINHEAD--
USE [EfficiencyDev]
GO

/****** Object:  UserDefinedFunction [dbo].[ufn_ArrowheadCU_Members_ALPHA]    Script Date: 10/16/2015 2:22:15 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO




CREATE FUNCTION [dbo].[ufn_ArrowheadCU_Members_ALPHA] (
	
	@Lens VARCHAR(50) = 'Init'
	,@StartDate DATE = NULL
	,@EndDate DATE = NULL

)

RETURNS TABLE

AS

RETURN (

	/********************************************************************************************************

	Title:					ufn_ArrowheadCU_Members
	Query Notes:			Data Model - ufn_ArrowheadCU_Members
								Organize and define all Arrowhead Credit Union Member information
								Defined Lens
									‘:Members/’
										‘:Members/Contacts/’
										‘:Members/Names/’
											':Members/Names/'
											':Members/Names/OpenPromos/'
											':Members/Names/UnsecuredBalances/'
											':Members/Names/LoanModifications/'
											':Members/Names/LoanDenials/'
										‘:Members/Products/’
											‘:Members/Products/LoanTrackings/’
											‘:Members/Products/LoanTransactions/’

	Server Used:			ACUREPORTS\ACUREPORTS
	Database Used:			SymitarExtracts
	Date Last Updated:		08/05/2015
	Change Log:				Please see the end of file.

	********************************************************************************************************/
--:ENDHEAD--
	
--:BEGINBODY--
	WITH
	
	/*********************************************************

		MEMBERS
		
	*********************************************************/
	
	--Initialize Members Information. Unique on account number
	InitMembersCTE AS (
	
		SELECT 
			Account.AccountNumber 
			,Account.Userchar3 AS 'UniqueID'
			,Account.Type AS 'AccountType'
			,RecordTypes.description AS 'AccountTypeDescription'
			,Account.OpenDate AS 'AccountOpenDate'
			,Account.CloseDate AS 'AccountCloseDate'
			,Account.BRANCH AS 'BranchAssignment'
			,GIS_ACU_Locations.Name AS 'BranchName'
			,GIS_ACU_Locations.Street AS 'BranchStreet'
			,GIS_ACU_Locations.City AS 'BranchCity'
			,GIS_ACU_Locations.State AS 'BranchState'
			,GIS_ACU_Locations.Zip AS 'BranchZip'
			,GIS_ACU_Locations.Ext AS 'BranchExt'
			,GIS_ACU_Locations.Latitude AS 'BranchLatitude' 
			,GIS_ACU_Locations.Longitude AS 'BranchLongitude'
			,GIS_ACU_Locations.GeoCodeType AS 'BranchGeoCodeType'
		FROM
			SymitarExtracts.dbo.Account
			LEFT OUTER JOIN SymitarParameters.dbo.RecordTypes
				ON	Account.Type = RecordTypes.number
					AND RecordTypes.type = 'ACCOUNTTYPE'
			LEFT OUTER JOIN BusinessIntelligenceDev.dbo.GIS_ACU_Locations
				ON Account.Branch = GIS_ACU_Locations.BranchNum
	),



		/*************************************************
			Member Contacts
		**************************************************/

			/* BEGIN Best Contact Info */

				--Extract active physical address for MembersCTE Initialization
				PhysicalContactCTE AS (
	
					SELECT 
						parentaccount
						,SSN
						,First AS 'PhysicalFirst'
						,Middle AS 'PhysicalMiddle'
						,Last AS 'PhysicalLast'
						,type AS 'NameType'
						,STREET AS 'PhysicalStreet'
						,CITY AS 'PhysicalCity'
						,State AS 'PhysicalState'
						,ZIPCODE AS 'PhysicalZipcode'
						,email  AS 'PhysicalEmail'
						,HOMEPHONE  AS 'PhysicalHomePhone'
						,MOBILEPHONE AS 'PhysicalMobilePhone'
						,WORKPHONE AS 'PhysicalWorkPhone'
						,BIRTHDATE AS 'PhysicalBirthDate'
						,ordinal AS 'PhysicalOrdinal'
						,MIN(ORDINAL) OVER (PARTITION BY parentaccount) AS 'MinPhysicalOrdinal'
					FROM 
						SymitarExtracts.dbo.Name
					WHERE 
						type = 0
						AND EXPIRATIONDATE IS NULL
						--AND (street NOT LIKE '' AND city NOT LIKE '' AND STATE NOT LIKE '' AND Zipcode NOT LIKE '')
				),

				--Extract active mailing address for MembersCTE Initialization
				MailContactCTE AS (
	
					SELECT DISTINCT
						PARENTACCOUNT
						,SSN AS 'MailSSN'
						,First AS 'MailFirst'
						,Middle AS 'MailMiddle'
						,Last AS 'MailLast'
						,type AS 'NameType'
						,Street AS 'MailStreet'
						,City AS 'MailCity'
						,State AS 'MailState'
						,Zipcode AS 'MailZipcode'
						,email AS 'MailEmail'
						,HOMEPHONE AS 'MailHomePhone'
						,MOBILEPHONE AS 'MailMobilePhone'
						,WORKPHONE AS 'MailWorkPhone'
						,ordinal AS 'MailOrdinal'
						,MIN(ORDINAL) OVER (PARTITION BY parentaccount) AS 'MinMailOrdinal'
					FROM 
						SymitarExtracts.dbo.Name
					WHERE 
						type = 2
						AND EXPIRATIONDATE IS NULL
						AND MAILOVERRIDE = 1
						AND (street NOT LIKE '' AND city NOT LIKE '' AND STATE NOT LIKE '' AND Zipcode NOT LIKE '')

				),

			/* END Best Contact Info */
		
			--Initialize Contact. Unique on parentaccount
			InitMemberContactsCTE AS (
			
				SELECT
					PhysicalContactCTE.ParentAccount AS 'ContactParentAccount'
					,PhysicalContactCTE.SSN AS 'PrimarySSN'
					,RTRIM(PhysicalContactCTE.PhysicalFirst) AS 'PrimaryFirst'
					,RTRIM(PhysicalContactCTE.PhysicalMiddle) AS 'PrimaryMiddle'
					,RTRIM(PhysicalContactCTE.PhysicalLast) AS 'PrimaryLast'
					,RTRIM(ISNULL(MailContactCTE.Nametype, PhysicalContactCTE.NameType)) AS 'ContactNameType'
					,Nametypes.name AS 'ContactNameTypeDescription'
					,CASE	WHEN (MailContactCTE.MailHomePhone IS NULL OR MailContactCTE.MailHomePhone = '') 
							THEN PhysicalContactCTE.PhysicalHomePhone
							ELSE MailContactCTE.MailHomePhone 
					END AS 'ContactHomePhone'
					,CASE	WHEN (MailContactCTE.MailMobilePhone IS NULL OR MailContactCTE.MailMobilePhone = '') 
							THEN PhysicalContactCTE.PhysicalMobilePhone 
							ELSE MailContactCTE.MailMobilePhone
					END AS 'ContactMobilePhone'
					,CASE	WHEN (MailContactCTE.MailWorkPhone IS NULL OR MailContactCTE.MailWorkPhone = '') 
							THEN PhysicalContactCTE.PhysicalWorkPhone 
							ELSE MailContactCTE.MailWorkPhone 
					END AS 'ContactWorkPhone'
					,RTRIM(CASE WHEN (MailContactCTE.MailEmail IS NULL OR MailContactCTE.MailEmail = '') 
								THEN PhysicalContactCTE.PhysicalEmail 
								ELSE MailContactCTE.MailEmail 
							END) AS 'ContactEmail'
					,RTRIM(ISNULL(MailContactCTE.MailStreet, PhysicalContactCTE.PhysicalStreet)) AS 'ContactStreet'
					,RTRIM(ISNULL(MailContactCTE.MailCity, PhysicalContactCTE.PhysicalCity)) AS 'ContactCity'
					,RTRIM(ISNULL(MailContactCTE.MailState, PhysicalContactCTE.PhysicalState)) AS 'ContactState'
					,RTRIM(ISNULL(MailContactCTE.MailZipcode, PhysicalContactCTE.PhysicalZipcode)) AS 'ContactZipcode'
				FROM
					PhysicalContactCTE
					LEFT OUTER JOIN MailContactCTE
						ON	MailContactCTE.ParentAccount = PhysicalContactCTE.ParentAccount
							AND MailContactCTE.MinMailOrdinal = MailContactCTE.MailOrdinal
					LEFT OUTER JOIN SymitarParameters.dbo.NameTypes
						ON	NameTypes.number = ISNULL(MailContactCTE.Nametype, PhysicalContactCTE.NameType)
				WHERE
					PhysicalContactCTE.MinPhysicalOrdinal = PhysicalContactCTE.PhysicalOrdinal
			 

			),




		/*************************************************
			Member Name Types
		**************************************************/

			/* BEGIN SSN */

				--Charge off accounts CTE. Use to extract SSNs that have a CO account share or loan, and accounts.
				FlagSSNChargeOffCTE AS (	
					SELECT 
						name.SSN AS 'ChargeOffSSN'
						,CASE	WHEN SUM(CASE	WHEN (ACCOUNT.type = 9999
													OR (SAVINGS.description LIKE 'C/O -%' OR SAVINGS.description LIKE 'P C/O -%'OR SAVINGS.chargeoffdate IS NOT NULL OR SAVINGS.chargeofftype <> 0 OR SAVINGS.type IN (998,999))
													OR (loan.type IN (999,6999) 
													OR loan.chargeoffdate IS NOT NULL))
												THEN 1 
												ELSE 0 
										END) > 0 
								THEN 1 
								ELSE 0 
						END AS 'ChargeOffFlag' 
					FROM
						SymitarExtracts.dbo.name
						--Use this to find CO Accounts
						JOIN SymitarExtracts.dbo.ACCOUNT
							ON ACCOUNT.accountnumber = name.PARENTACCOUNT
						--Use this to find CO Shares
						LEFT OUTER JOIN SymitarExtracts.dbo.loan
							ON loan.PARENTACCOUNT = name.PARENTACCOUNT
						--Use this to find CO Loans
						LEFT OUTER JOIN SymitarExtracts.dbo.SAVINGS
							ON SAVINGS.parentaccount = name.parentaccount
					WHERE
						name.type = 0 
						AND name.EXPIRATIONDATE IS NULL
					GROUP BY
						name.SSN
				),

				--Previous Promo CTE. Use to extract SSN that have opened, and have not closed, an unsecured a promo within the last year
				FlagSSNOpenPromoCTE AS (
	
					SELECT
						name.SSN AS 'OpenPromoSSN'
						,CASE	WHEN COUNT(Events_Promotions.IsSecured) > 0 
								THEN 1 
								ELSE 0 
						END AS 'OpenPromoFlag'
					FROM 
						SymitarExtracts.dbo.name
						--Use this to find open loans
						LEFT OUTER JOIN SymitarExtracts.dbo.loan
							ON	loan.PARENTACCOUNT = name.parentaccount 
								AND loan.CLOSEDATE IS NULL
						--Use this to extract promoid from loantracking
						LEFT OUTER JOIN SymitarExtracts.dbo.LOANTRACKING
							ON	LOANTRACKING.PARENTACCOUNT = loan.PARENTACCOUNT 
								AND LOANTRACKING.PARENTID = loan.id 
								AND LOANTRACKING.type = 35
						--Use to dynamically extract accounts that have an opened unsecured promo within the last year by joining to updated Promotions Schema. Ensure that the events_promotions table has been updated. Currently a manual proces (1/23/2015)
						LEFT OUTER JOIN BusinessIntelligenceDev.dbo.Events_Promotions
							ON	Events_Promotions.PromoID = LOANTRACKING.userchar10 
								AND DATEDIFF(dd,Events_Promotions.ExpirationDate,getdate()) <= 365
								AND Events_Promotions.IsSecured = 0
					WHERE 
						name.type = 0 
						AND name.EXPIRATIONDATE IS NULL
					GROUP BY
						name.SSN

				),

				--UnsecuredBalanceCTE. Use to extract the aggregate unsecured balance by SSN
				SSNUnsecuredBalanceCTE AS (	
		
						SELECT 
							name.SSN AS 'UnsecuredBalanceSSN'
							,CASE	WHEN SUM(CASE	WHEN DimLoanProduct.loantype IS NOT NULL 
													THEN CASE	WHEN (loan.balance > loan.creditlimit) 
																THEN loan.balance 
																ELSE loan.creditLimit 
														END
													ELSE 0
											END) > 0 
									THEN SUM(CASE	WHEN DimLoanProduct.loantype IS NOT NULL 
													THEN CASE	WHEN (loan.balance > loan.creditlimit) 
																THEN loan.balance 
																ELSE loan.creditLimit 
														END
													ELSE 0
										END)
									ELSE 0
							END	AS 'UnsecuredAggregateBalance'		--Added nested case to make NULLs 0 agg bal
						FROM
							SymitarExtracts.dbo.name
							--Use to extract open loan balances
							LEFT OUTER JOIN symitarextracts.dbo.loan
								ON	loan.parentaccount = name.PARENTACCOUNT 
									AND loan.CLOSEDATE IS NULL
							--Use to dynamically find unsecured loans. Ensure dimloanproduct table has been updated. Currently a manual process (1/23/2015)
							LEFT OUTER JOIN [Efficiency].[dbo].[DimLoanProduct]
								ON	DimLoanProduct.loantype = loan.type 
									AND DimLoanProduct.active = 1 
									AND DimLoanProduct.IsSecured = 0
						WHERE
							name.type = 0 
							AND name.EXPIRATIONDATE IS NULL
						GROUP BY 
							name.SSN

				),

				--Loan Modification CTE. Use to extract accounts that have had a loan mod. Yields a flag per SSN  
				FlagSSNLoanModCTE AS (

					SELECT 
						name.SSN AS 'LoanModSSN'
						,CASE	WHEN COUNT(LOANTRACKING.type) > 0 
								THEN 1 
								ELSE 0 
						END AS 'LoanModFlag'
					FROM
						SymitarExtracts.dbo.name
						--Use this to tie loan tracking to loan that is open or closed within last 365 days.
						LEFT OUTER JOIN SymitarExtracts.dbo.loan
							ON	loan.parentaccount = name.PARENTACCOUNT 
								AND (loan.closedate IS NULL OR DATEDIFF(dd,loan.closedate, getdate()) < 365)
						--Use this to extract loan mod tacking 44 from loan tracking
						LEFT OUTER JOIN SymitarExtracts.dbo.LOANTRACKING
							ON	LOANTRACKING.PARENTACCOUNT = loan.PARENTACCOUNT 
								AND LOANTRACKING.PARENTID = loan.id 
								AND LOANTRACKING.type = 44
					WHERE
						name.type = 0 
						AND name.EXPIRATIONDATE IS NULL
					GROUP BY
						name.SSN

				),


				--Loan Denial CTE. Use to find accounts that have been denied for a loan within the last year (DLC)
				FlagSSNLoanDenialCTE AS (

					SELECT
						name.SSN AS 'LoanDenialSSN'
						,CASE	WHEN COUNT(Process.Status) > 0 
								THEN 1 
								ELSE 0 
						END AS 'LoanDenialFlag'
					FROM 
						SymitarExtracts.dbo.name
						--Use to dynamically extract accounts that have been denied a loan within last 365 days
						LEFT OUTER JOIN [ACNETSQLSVR01].[DLC].[dbo].[Process]
							ON	name.PARENTACCOUNT = RIGHT('0000000000'+ Process.AcctNo,10) 
								AND Process.status LIKE '%DISAPPROVED%' 
								AND DATEDIFF(dd,Process.DateTimeEnd,getdate()) <= 365
					WHERE 
						name.type = 0 
						AND name.EXPIRATIONDATE IS NULL
					GROUP BY
						name.SSN
				),
		
			/* END SSN */

			--Initialize GIS data. Tied to members names for geospatial mapping. Separated from InitMembersNameTypesCTE due to dev process. Consider adding to name cte once process proven and if efficient
			InitMembersGISLocationCTE AS (

				SELECT
					[GISLocationID] AS 'GISLocationID'
					,[ParentAccount] AS 'GISParentAccount'
					,[geocode_datetime] AS 'GISGeoCodeDatetime'
					,[full_address] AS 'GISFullAddress'
					,[address_type] AS 'GISNameType'
					,[return_address] AS 'GISReturnAddress'
					,[geocode_address_type] AS 'GISGeoCodeAddressType'
					,[geocode_score] AS 'GISGeoCodeScore'
					,[longitude] AS 'GISLongitude'
					,[latitude] AS 'GISLatitude'
					,[min_longitude] AS 'GISMinLongitude'
					,[max_longitude] AS 'GISMaxLongitude'
					,[max_latitude] AS 'GISMaxLatitude'
					,[min_latitude] AS 'GISMinLatitude'
					,[accuracy] AS 'GISAccuracy'
					,[geolocator_type] AS 'GISGeoLocatorType'
					,[Organization] AS 'GISOrganization'
					,[Description] AS 'GISDescription'
				FROM
					EfficiencyDev.dbo.TEMP_GIS_Locations
			),


			--Initialize Member Names infomation. Unique on Account, SSN, NameType, NameTypeOrdinal. Should we break out each flag to be called? (i.e Members/Names/ChargedOff/)
			InitMembersNameTypesCTE AS (

				SELECT
					Name.ParentAccount AS 'NameTypeParentAccount'
					,Name.Type AS 'NameType'
					,NameTypes.Name AS 'NameTypeDescription'
					,Name.Ordinal AS 'NameTypeOrdinal'
					,Name.Locator AS 'NameTypeLocator'
					,Name.EXPIRATIONDATE AS 'NameTypeExpiration'
					,Name.LASTADDRCHGDATE AS 'NameTypeAddressChangeDate'
					,Name.MAILOVERRIDE AS 'NameTypeMailOverride'
					,Name.SSNTYPE AS 'NameTypeSSNType'
					,Name.SSN AS 'NameTypeSSN'
					,Name.Birthdate AS 'NameTypeBirthDate'
					,Name.DeathDate AS 'NameTypeDeathDate'
					,Name.Title AS 'NameTypeTitle'
					,Name.First AS 'NameTypeFistName'
					,Name.Middle AS 'NameTypeMiddleName'
					,Name.Last AS 'NameTypeLastName'
					,Name.Suffix AS 'NameTypeSuffix'
					,Name.ExtraAddress AS 'NameTypeExtraAddress'
					,Name.Street AS 'NameTypeStreet'
					,Name.City AS 'NameTypeCity'
					,Name.State AS 'NameTypeState'
					,Name.Zipcode AS 'NameTypeZipcode'
					,Name.Email AS 'NameTypeEmail'
					,Name.HomePhone AS 'NameTypeHomePhone'
					,Name.MobilePhone AS 'NameTypeMobilePhone'
					,Name.WorkPhone AS 'NameTypeWorkPhone'
					,Name.WorkPhoneExtension AS 'NameTypeWorkPhoneExtension'
					--,SSNChargeOffCTE.ChargeOffFlag AS 'NametypeChargeOffFlag'
					--,SSNOpenPromoCTE.OpenPromoFlag AS 'NametypeOpenPromoFlag'
					--,SSNUnsecuredBalanceCTE.UnsecuredAggregateBalance AS 'NametypeUnsecuredAggregateBalance'
					--,SSNLoanModCTE.LoanModFlag AS 'NametypeLoanModFlag'
					--,SSNLoanDenialCTE.LoanDenialFlag AS 'NametypeLoanDenialFlag'
				FROM
					SymitarExtracts.dbo.Name
					LEFT OUTER JOIN SymitarParameters.dbo.NameTypes
						ON	Name.type = NameTypes.number
					--LEFT OUTER JOIN SSNChargeOffCTE
					--	ON	Name.SSN = SSNChargeOffCTE.ChargeOffSSN
					--		AND (@Lens LIKE '%:Members/Names/ChargeOff/%')
					--LEFT OUTER JOIN SSNOpenPromoCTE
					--	ON Name.SSN = SSNOpenPromoCTE.OpenPromoSSN
					--LEFT OUTER JOIN SSNUnsecuredBalanceCTE
					--	ON Name.SSN = SSNUnsecuredBalanceCTE.UnsecuredBalanceSSN
					--LEFT OUTER JOIN SSNLoanModCTE
					--	ON Name.SSN = SSNLoanModCTE.LoanModSSN
					--LEFT OUTER JOIN SSNLoanDenialCTE
					--	ON Name.SSN = SSNLoanDenialCTE.LoanDenialSSN
				--WHERE
				--	(@Lens LIKE '%:Members/Names/%')
						

				),

		
		/*************************************************
			Account Tracking
		**************************************************/

		--Initialize AccountTracking Information. Unique on parentaccount, tracking type
		--InitLoanTrackingsCTE AS (

		--	SELECT
		--		'Loan' AS 'LoanTrackingType'
		--		,LoanTracking.ParentAccount AS 'LoanTrackingParentAccount'
		--		,LoanTracking.ParentID AS 'LoanTrackingParentID'
		--		,LoanTracking.type AS 'LoanTrackingNumber'
		--		,TrackingRecordTypes.description AS 'LoanTrackingTypeDescription'
		--		,LoanTracking.Ordinal AS 'LoanTrackingOrdinal'
		--		,LoanTracking.CreationDate AS 'LoanTrackingCreationDate'
		--		,LoanTracking.CreationTime AS 'LoanTrackingCreationTime'
		--		,LoanTracking.ExpireDate AS 'LoanTrackingExpirationDate'
		--		,LoanTracking.FMLASTDATE AS 'LoanTrackingLastFMDate'
		--		,LoanTracking.RecordChangeDate AS 'LoanTrackingRecordChangeDate'
		--		,UserNumber1 AS 'LoanTrackingUserNumber1'
		--		,UserNumber2 AS 'LoanTrackingUserNumber2'
		--		,UserNumber3 AS 'LoanTrackingUserNumber3'
		--		,UserNumber4 AS 'LoanTrackingUserNumber4'
		--		,UserNumber5 AS 'LoanTrackingUserNumber5'
		--		,UserNumber6 AS 'LoanTrackingUserNumber6'
		--		,UserNumber7 AS 'LoanTrackingUserNumber7'
		--		,UserNumber8 AS 'LoanTrackingUserNumber8'
		--		,UserNumber9 AS 'LoanTrackingUserNumber9'
		--		,UserNumber10 AS 'LoanTrackingUserNumber10'
		--		,Usernumber11 AS 'LoanTrackingUsernumber11'
		--		,Usernumber12 AS 'LoanTrackingUsernumber12'
		--		,Usernumber13 AS 'LoanTrackingUsernumber13'
		--		,Usernumber14 AS 'LoanTrackingUsernumber14'
		--		,Usernumber15 AS 'LoanTrackingUsernumber15'
		--		,Usernumber16 AS 'LoanTrackingUsernumber16'
		--		,Usernumber17 AS 'LoanTrackingUsernumber17'
		--		,Usernumber18 AS 'LoanTrackingUsernumber18'
		--		,Usernumber19 AS 'LoanTrackingUsernumber19'
		--		,Usernumber20 AS 'LoanTrackingUsernumber20'

		--		,UserChar1 AS 'LoanTrackingUserChar1'
		--		,UserChar2 AS 'LoanTrackingUserChar2'
		--		,UserChar3 AS 'LoanTrackingUserChar3'
		--		,UserChar4 AS 'LoanTrackingUserChar4'
		--		,UserChar5 AS 'LoanTrackingUserChar5'
		--		,UserChar6 AS 'LoanTrackingUserChar6'
		--		,UserChar7 AS 'LoanTrackingUserChar7'
		--		,UserChar8 AS 'LoanTrackingUserChar8'
		--		,UserChar9 AS 'LoanTrackingUserChar9'
		--		,UserChar10 AS 'LoanTrackingUserChar10'
		--		,UserChar11 AS 'LoanTrackingUserChar11'
		--		,UserChar12 AS 'LoanTrackingUserChar12'
		--		,UserChar13 AS 'LoanTrackingUserChar13'
		--		,UserChar14 AS 'LoanTrackingUserChar14'
		--		,UserChar15 AS 'LoanTrackingUserChar15'
		--		,UserChar16 AS 'LoanTrackingUserChar16'
		--		,UserChar17 AS 'LoanTrackingUserChar17'
		--		,UserChar18 AS 'LoanTrackingUserChar18'
		--		,UserChar19 AS 'LoanTrackingUserChar19'
		--		,UserChar20 AS 'LoanTrackingUserChar20'
      
		--		,UserAmount1 AS 'LoanTrackingUserAmount1'
		--		,UserAmount2 AS 'LoanTrackingUserAmount2'
		--		,UserAmount3 AS 'LoanTrackingUserAmount3'
		--		,UserAmount4 AS 'LoanTrackingUserAmount4'
		--		,UserAmount5 AS 'LoanTrackingUserAmount5'
		--		,UserAmount6 AS 'LoanTrackingUserAmount6'
		--		,UserAmount7 AS 'LoanTrackingUserAmount7'
		--		,UserAmount8 AS 'LoanTrackingUserAmount8'
		--		,UserAmount9 AS 'LoanTrackingUserAmount9'
		--		,UserAmount10 AS 'LoanTrackingUserAmount10'
		--		,UserAmount11 AS 'LoanTrackingUserAmount11'
		--		,UserAmount12 AS 'LoanTrackingUserAmount12'
		--		,UserAmount13 AS 'LoanTrackingUserAmount13'
		--		,UserAmount14 AS 'LoanTrackingUserAmount14'
		--		,UserAmount15 AS 'LoanTrackingUserAmount15'
		--		,UserAmount16 AS 'LoanTrackingUserAmount16'
		--		,UserAmount17 AS 'LoanTrackingUserAmount17'
		--		,UserAmount18 AS 'LoanTrackingUserAmount18'
		--		,UserAmount19 AS 'LoanTrackingUserAmount19'
		--		,UserAmount20 AS 'LoanTrackingUserAmount20'
     
		--		,Usercode1 AS 'LoanTrackingUsercode1'
		--		,Usercode2 AS 'LoanTrackingUsercode2'
		--		,Usercode3 AS 'LoanTrackingUsercode3'
		--		,Usercode4 AS 'LoanTrackingUsercode4'
		--		,Usercode5 AS 'LoanTrackingUsercode5'
		--		,Usercode6 AS 'LoanTrackingUsercode6'
		--		,Usercode7 AS 'LoanTrackingUsercode7'
		--		,Usercode8 AS 'LoanTrackingUsercode8'
		--		,Usercode9 AS 'LoanTrackingUsercode9'
		--		,Usercode10 AS 'LoanTrackingUsercode10'
		--		,UserCode11 AS 'LoanTrackingUsercode11'
		--		,UserCode12 AS 'LoanTrackingUsercode12'
		--		,UserCode13 AS 'LoanTrackingUsercode13'
		--		,UserCode14 AS 'LoanTrackingUsercode14'
		--		,UserCode15 AS 'LoanTrackingUsercode15'
		--		,UserCode16 AS 'LoanTrackingUsercode16'
		--		,UserCode17 AS 'LoanTrackingUsercode17'
		--		,UserCode18 AS 'LoanTrackingUsercode18'
		--		,UserCode19 AS 'LoanTrackingUsercode19'
		--		,UserCode20 AS 'LoanTrackingUsercode20'
      
		--		,UserDate1 AS 'LoanTrackingUserDate1'
		--		,UserDate2 AS 'LoanTrackingUserDate2'
		--		,UserDate3 AS 'LoanTrackingUserDate3'
		--		,UserDate4 AS 'LoanTrackingUserDate4'
		--		,UserDate5 AS 'LoanTrackingUserDate5'
		--		,UserDate6 AS 'LoanTrackingUserDate6'
		--		,UserDate7 AS 'LoanTrackingUserDate7'
		--		,UserDate8 AS 'LoanTrackingUserDate8'
		--		,UserDate9 AS 'LoanTrackingUserDate9'
		--		,UserDate10 AS 'LoanTrackingUserDate10'
		--		,UserDate11 AS 'LoanTrackingUserDate11'
		--		,UserDate12 AS 'LoanTrackingUserDate12'
		--		,UserDate13 AS 'LoanTrackingUserDate13'
		--		,UserDate14 AS 'LoanTrackingUserDate14'
		--		,UserDate15 AS 'LoanTrackingUserDate15'
		--		,UserDate16 AS 'LoanTrackingUserDate16'
		--		,UserDate17 AS 'LoanTrackingUserDate17'
		--		,UserDate18 AS 'LoanTrackingUserDate18'
		--		,UserDate19 AS 'LoanTrackingUserDate19'
		--		,UserDate20 AS 'LoanTrackingUserDate20'

		--		,UserRate1 AS 'LoanTrackingUserRate1'
		--		,UserRate2 AS 'LoanTrackingUserRate2'
		--		,UserRate3 AS 'LoanTrackingUserRate3'
		--		,UserRate4 AS 'LoanTrackingUserRate4'
		--		,UserRate5 AS 'LoanTrackingUserRate5'
		--		,UserRate6 AS 'LoanTrackingUserRate6'
		--		,UserRate7 AS 'LoanTrackingUserRate7'
		--		,UserRate8 AS 'LoanTrackingUserRate8'
		--		,UserRate9 AS 'LoanTrackingUserRate9'
		--		,UserRate10 AS 'LoanTrackingUserRate10'
		--		,UserRate11 AS 'LoanTrackingUserRate11'
		--		,UserRate12 AS 'LoanTrackingUserRate12'
		--		,UserRate13 AS 'LoanTrackingUserRate13'
		--		,UserRate14 AS 'LoanTrackingUserRate14'
		--		,UserRate15 AS 'LoanTrackingUserRate15'
		--		,UserRate16 AS 'LoanTrackingUserRate16'
		--		,UserRate17 AS 'LoanTrackingUserRate17'
		--		,UserRate18 AS 'LoanTrackingUserRate18'
		--		,UserRate19 AS 'LoanTrackingUserRate19'
		--		,UserRate20 AS 'LoanTrackingUserRate20'
		--	FROM
		--		SymitarExtracts.dbo.LOANTRACKING
		--		JOIN UniqueLoanTrackingCTE
		--			ON	LoanTracking.ParentAccount = UniqueLoanTrackingCTE.ParentAccount 
		--				AND LoanTracking.ParentID = UniqueLoanTrackingCTE.ParentID 
		--				AND LoanTracking.Type = UniqueLoanTrackingCTE.TYPE
		--				AND UniqueLoanTrackingCTE.MaxLocator = UniqueLoanTrackingCTE.Locator
		--		LEFT OUTER JOIN SymitarParameters.dbo.TrackingRecordTypes
		--			ON	LoanTracking.type = TrackingRecordTypes.number
		--				AND TrackingRecordTypes.level = 'LOAN'

		--),

	/*********************************************************

		Products - SHARES AND LOANS

	*********************************************************/

	InitProductsCTE AS (

		SELECT
			ParentAccount AS 'ProductParentAccount'
			,'Share' AS 'ProductType'
			,Type AS 'ProductTypeNumber'
			,ID AS 'ProductID'
			,NULL AS 'ProductCollateralCode'
			,Savings.DESCRIPTION AS 'ProductDescription'
			,Savings.Branch AS 'ProductBranch'
			,Savings.CreatedByUser AS 'ProductCreator'
			,Savings.OpenDate AS 'ProductOpenDate'
			,Savings.CloseDate AS 'ProductCloseDate'
			--Trial Balance seems to only look at chargeoffdate for chargeoff shares
			,CASE	WHEN	SAVINGS.description LIKE 'C/O -%' 
							OR SAVINGS.chargeoffdate IS NOT NULL 
							--OR SAVINGS.chargeofftype <> 0  Need to validate this.
							OR SAVINGS.type IN (998,999)
					THEN 1
					ELSE 0
			END AS 'ProductChargeOffFlag'
			,CASE	WHEN	SAVINGS.description LIKE 'P C/O -%'
							AND SAVINGS.chargeoffdate IS NULL
							AND SAVINGS.type IN (998,999)
					THEN 1
					ELSE 0
			END AS 'ProductPartialChargeOffFlag'	
			,NULL AS 'ProductExperianBureauScore'
			,Savings.Balance AS 'ProductBalance'
			,Savings.OriginalBalance AS 'ProductOriginalBalance'
			,Savings.MinimumBalance AS 'ProductMinimumBalance'
			,Savings.ChargeoffAmount AS 'ProductChargeOffAmount'
			,Savings.ChargeoffType AS 'ProductChargeOffType'
			,Savings.ChargeOffDate AS 'ProductChargeOffDate'
			,NULL AS 'ProductCreditLimit'
			,NULL AS 'ProductPayment'
			,NULL AS 'ProductTerm'
			,Savings.DivRate AS 'ProductInterestRate'
			,NULL AS 'ProductLastPaymentDate'
			,NULL AS 'ProductPaymentsMade'
			,Savings.MaturityDate AS 'ProductMaturityDate'
			,Savings.RenewShareType AS 'ProductRenewType'
			,NULL AS 'ProductInterestUnpaid'
			,-Savings.DivFromOpen AS 'ProductInterestFromOpen'
			,-Savings.DivYTD AS 'ProductInterestYTD'
			,-Savings.DivLastYear AS 'ProductInterestLastYear'
			,Savings.OverdraftTolerance AS 'ProductOverdraftTolerance'
			,Savings.OVERDRAFTFEEYTD AS 'ProductOverdraftFeeYTD'
			,Savings.OVERDRAFTFEELASTYR AS 'ProductOverdraftFeeLastYear'
			,Savings.NSFYTD AS 'ProductNSFYTD'	--Should this be NSFFeeYTD?
			,Savings.NSFLastYear AS 'ProductNSFLastYear'	--SHOULD this be NSFFeeLY
			,Savings.CourtesyPayYTD AS 'ProductCourtesyPayYTD'	--Should this be CourtesyPayFeeYtd?
			,Savings.CourtesyPayLastYear AS 'ProductCourtesyPayLastYear'	--Should this be CourtesyPayFeeLY
			,NULL  AS 'ProductFeesYTD'
			,NULL AS 'ProductFeesLastYear'
			,NULL AS 'ProductLateChargeUnpaid'
			,NULL AS 'ProductLateChargeYTD'
			,NULL AS 'ProductLateChargeLastYear'

			,NULL AS 'ProductCategoryID'
			,NULL AS 'ProductGeneralCategory'
			,NULL AS 'ProductBSCat'
			,NULL AS 'ProductNewBalanceSheetCategory'
			,NULL AS 'ProductLoanTypesId'
			,NULL AS 'ProductSymDescription'
			,NULL AS 'ProductCategory'
			,NULL AS 'ProductSuperCategory'
			,NULL AS 'ProductServiceClassMCIF'
			,NULL AS 'ProductApplicableScorecard'
			,NULL AS 'ProductIndirect'
			,NULL AS 'ProductSecured'
			,NULL AS 'ProductFixedRate'
			,NULL AS 'ProductMixedTiers'
			,NULL AS 'ProductMaxTerm'
			,NULL AS 'ProductOLDGLNumber'
			,NULL AS 'ProductNewGLNumber'
			,NULL AS 'ProductGLSuffix'
			,NULL AS 'ProductLoanType4Digit'
			,NULL AS 'ProductReserveCategory'
			,NULL AS 'ProductCredMgrCategory'
		FROM
			SymitarExtracts.dbo.Savings

		UNION

		SELECT
			Loan.ParentAccount AS 'LoanParentAccount'
			,'Loan' AS 'LoanType'
			,Loan.Type AS 'LoanTypeNumber'
			,Loan.ID AS 'LoanID'
			,Loan.CollateralCode AS 'LoanCollateralCode'
			,Loan.DESCRIPTION AS 'LoanDescription'
			,Loan.Branch AS 'LoanBranch'
			,Loan.CREATEDBYUSER AS 'LoanCreator'
			,Loan.OpenDate AS 'LoanOpenDate'
			,Loan.CloseDate AS 'LoanCloseDate'
			,CASE	WHEN	Loan.type IN (999,6999) 
							OR Loan.chargeoffdate IS NOT NULL
					THEN 1
					ELSE 0
			END AS 'LoanChargeOffFlag'
			,NULL AS 'LoanPartialChargeOffFlag'
			,Loan.BureauScore1 AS 'LoanExperianBureauScore'
			,Loan.BALANCE AS 'LoanBalance'
			,Loan.OriginalBalance AS 'LoanOriginalBalance'
			,NULL AS 'ProductMinimumBalance'
			,Loan.ChargeOffAmount AS 'LoanChargeOffAmount'
			,Loan.CHARGEOFFTYPE AS 'LoanChargeOffType'
			,Loan.ChargeOffDate AS 'LoanChargeOffDate'
			,Loan.CreditLimit AS 'LoanCreditLimit'
			,Loan.Payment AS 'LoanPayment'
			,Loan.PaymentCount AS 'LoanTerm'
			,Loan.InterestRate AS 'LoanInterestRate'
			,Loan.LASTPAYMENTDATE AS 'LoanLastPaymentDate'
			,Loan.PaymentHistory1 AS 'LoanPaymentsMade'
			,NULL AS 'ProductMaturityDate'
			,NULL AS 'ProductRenewType'
			,Loan.InterestUnpaid AS 'LoanInterestUnpaid'
			,Loan.INTERESTFROMOPEN AS 'LoanInterestFromOpen'
			,Loan.InterestYTD AS 'LoanInterestYTD'
			,Loan.INTERESTLASTYEAR AS 'LoanInterestLastYear'
			,NULL AS 'ProductOverdraftTolerance'
			,NULL AS 'ProductOverdraftFeeYTD'
			,NULL AS 'ProductOverdraftFeeLastYear'
			,NULL AS 'ProductNSFYTD'
			,NULL AS 'ProductNSFLastYear'
			,NULL AS 'ProductCourtesyPayYTD'
			,NULL AS 'ProductCourtesyPayLastYear'
			,Loan.FeesYTD AS 'LoanFeesYTD'
			,Loan.FeesLastYear AS 'LoanFeesLastYear'
			,Loan.LateChargeUnpaid AS 'LoanLateChargeUnpaid'
			,Loan.LateChargeYTD AS 'LoanLateChargeYTD'
			,Loan.LateChargeLastYear AS 'LoanLateChargeLastYear'

			,DimLoanProduct.CategoryID
			,DimLoanProduct.GeneralCategory
			,LoanTypes.BalanceSheetCategory As 'BSCat'
			,DimLoanProduct.NewBalanceSheetCategory
			,LoanTypes.LoanTypesId
			,LoanTypes.SymDescription
			,LoanTypes.Category
			,LoanTypes.SuperCategory
			,LoanTypes.ServiceClassMCIF
			,LoanTypes.ApplicableScorecard
			,LoanTypes.Indirect
			,LoanTypes.Secured
			,LoanTypes.FixedRate
			,LoanTypes.MixedTiers
			,LoanTypes.MaxTerm
			,LoanTypes.OLDGLNumber
			,LoanTypes.NewGLNumber
			,LoanTypes.GLSuffix
			,LoanTypes.LoanType4Digit
			,LoanTypes.ReserveCategory
			,LoanTypes.CredMgrCategory
		FROM
			SymitarExtracts.dbo.Loan
			--Bring in Loan Product info
			LEFT OUTER JOIN [Efficiency].[dbo].[DimLoanProduct]
				ON	DimLoanProduct.LoanType = Loan.Type 
					AND DimLoanProduct.active = 1
			LEFT OUTER JOIN DecisionSupport.dbo.LoanTypes
				ON	Loan.Type = LoanTypes.LoanType
					AND Loan.CollateralCode = LoanTypes.CollateralCode

	),



	/********************
	Products Transactions
	*********************/

	--Initialize Loan Transactions. Unique on ParentAccount, ParentID, PostDate, PostTime, SequenceNumber, Amount
	InitTransactionsCTE AS (

		SELECT
				'Share' AS 'TransactionType'
				,SavingsTransaction.ParentAccount AS 'TransactionParentAccount'
				,SavingsTransaction.ParentID AS 'TransactionParentID'
				,SavingsTransaction.ActivityDate AS 'TransactionActivityDate'
				,SavingsTransaction.LastTranDate AS 'TransactionLastTranDate'
				,SavingsTransaction.EffectiveDate AS 'TransactionEffectiveDate'
				,SavingsTransaction.PostDate AS 'TransactionPostDate'
				,SavingsTransaction.PostTime As 'TransactionPostTime'
				,SavingsTransaction.Branch AS 'TransactionBranch'
				,SavingsTransaction.UserNumber AS 'TransactionUserNumber'
				,SavingsTransaction.UserOverride AS 'TransactionUserOverride'
				,SavingsTransaction.ProcessorUser AS 'TransactionProcessorUser'
				,SavingsTransaction.VoidCode AS 'TransactionVoidCode'
				,ABS(SavingsTransaction.BalanceChange)+SavingsTransaction.INTEREST AS 'TransactionAmount'
				,SavingsTransaction.BalanceChange AS 'TransactionBalanceChange'
				,SavingsTransaction.Interest AS 'TransactionInterest'
				,SavingsTransaction.NewBalance AS 'TransactionNewBalance'
				,SavingsTransaction.PrevAvailBalance AS 'TransactionPrevAvailBalance'
				,SavingsTransaction.Description AS 'TransactionDescription'
				,SavingsTransaction.ActionCode AS 'TransactionActionCode'
				,TransactionActionCodes.Name As 'TransactionActionCodeName'
				,SavingsTransaction.SourceCode AS 'TransactionSourceCode'
				,TransactionSourceCodes.Name AS 'TransactionSourceCodeName'
				,SavingsTransaction.SequenceNumber AS 'TransactionSequenceNumber'
				,SavingsTransaction.ConfirmationSeq AS 'TransactionConfirmationSeq'
				,SavingsTransaction.DraftNumber AS 'TransactionDraftNumber'
				,SavingsTransaction.TracerNumber AS 'TransactionTracerNumber'
				,SavingsTransaction.MicrAcctNum AS 'TransactionMicrAcctNum'
				,SavingsTransaction.CommentCode AS 'TransactionCommentCode'
				,SavingsTransaction.TransferCode AS 'TransactionTransferCode'
				,SavingsTransaction.AdjustmentCode AS 'TransactionAdjustmentCode'
				,SavingsTransaction.RecurringTran AS 'TransactionRecurringTran'
				,SavingsTransaction.FeeCountBy AS 'TransactionFeeCountBy'
				,CASE	WHEN	SavingsTransaction.SourceCode IN ('G', 'O')
								OR (SavingsTransaction.SourceCode = 'B' 
									AND SavingsTransaction.Description IS NOT NULL)
						THEN 1
						ELSE 0
				END AS 'CardTransactionFlag'		--Debit card transactions not including ATM transactions
			FROM
				SymitarExtracts.dbo.SavingsTransaction
				LEFT OUTER JOIN SymitarParameters.dbo.TransactionSourceCodes
					ON SavingsTransaction.Sourcecode = TransactionSourceCodes.Code
				LEFT OUTER JOIN SymitarParameters.dbo.TransactionActionCodes
					ON SavingsTransaction.ActionCode = TransactionActionCodes.Code
			--WHERE 
			--	( (@StartDate IS NULL AND SavingsTransaction.Postdate >= CONVERT(DATE,GETDATE()-1)) 
			--		OR (@StartDate IS NOT NULL AND SavingsTransaction.POSTDATE >= @StartDate))


				UNION


			SELECT
				'Loan' AS 'LoanTransactionType'
				,LoanTransaction.ParentAccount AS 'LoanTransactionParentAccount'
				,LoanTransaction.ParentID AS 'LoanTransactionParentID'
				,LoanTransaction.ActivityDate AS 'TransactionActivityDate'
				,LoanTransaction.LastTranDate AS 'TransactionLastTranDate'
				,LoanTransaction.EffectiveDate AS 'TransactionEffectiveDate'
				,LoanTransaction.PostDate AS 'TransactionPostDate'
				,LoanTransaction.PostTime As 'TransactionPostTime'
				,LoanTransaction.Branch AS 'TransactionBranch'
				,LoanTransaction.UserNumber AS 'TransactionUserNumber'
				,LoanTransaction.UserOverride AS 'TransactionUserOverride'
				,LoanTransaction.ProcessorUser AS 'TransactionProcessorUser'
				,LoanTransaction.VoidCode AS 'TransactionVoidCode'
				,ABS(LoanTransaction.BalanceChange)+LoanTransaction.INTEREST AS 'TransactionAmount'
				,LoanTransaction.BalanceChange AS 'TransactionBalanceChange'
				,LoanTransaction.Interest AS 'TransactionInterest'
				,LoanTransaction.NewBalance AS 'TransactionNewBalance'
				,LoanTransaction.PrevAvailBalance AS 'TransactionPrevAvailBalance'
				,LoanTransaction.Description AS 'TransactionDescription'
				,LoanTransaction.ActionCode AS 'TransactionActionCode'
				,TransactionActionCodes.Name As 'TransactionActionCodeName'
				,LoanTransaction.SourceCode AS 'TransactionSourceCode'
				,TransactionSourceCodes.Name AS 'TransactionSourceCodeName'
				,LoanTransaction.SequenceNumber AS 'TransactionSequenceNumber'
				,LoanTransaction.ConfirmationSeq AS 'TransactionConfirmationSeq'
				,LoanTransaction.DraftNumber AS 'TransactionDraftNumber'
				,LoanTransaction.TracerNumber AS 'TransactionTracerNumber'
				,LoanTransaction.MicrAcctNum AS 'TransactionMicrAcctNum'
				,LoanTransaction.CommentCode AS 'TransactionCommentCode'
				,LoanTransaction.TransferCode AS 'TransactionTransferCode'
				,LoanTransaction.AdjustmentCode AS 'TransactionAdjustmentCode'
				,LoanTransaction.RecurringTran AS 'TransactionRecurringTran'
				,LoanTransaction.FeeCountBy AS 'TransactionFeeCountBy'
				,NULL AS 'CardTransaction'
			FROM
				SymitarExtracts.dbo.LoanTransaction
				LEFT OUTER JOIN SymitarParameters.dbo.TransactionSourceCodes
					ON LoanTransaction.Sourcecode = TransactionSourceCodes.Code
				LEFT OUTER JOIN SymitarParameters.dbo.TransactionActionCodes
					ON LoanTransaction.ActionCode = TransactionActionCodes.Code
			--WHERE 
			--	( (@StartDate IS NULL AND LoanTransaction.Postdate >= CONVERT(DATE,GETDATE()-1)) 
			--		OR (@StartDate IS NOT NULL AND LoanTransaction.POSTDATE >= @StartDate))
	
	),

	/*********************************************************

		SHARES --Consider removing for above
		
	*********************************************************/
	
	InitSharesCTE AS (
		
		SELECT
			ParentAccount AS 'ShareParentAccount'
			,Type AS 'ShareType'
			,ID AS 'ShareID'
			,DESCRIPTION AS 'ShareDescription'
			,OPENDATE AS 'ShareOpenDate'
			,CLOSEDATE AS 'SharesCloseDate'
		FROM
			SymitarExtracts.dbo.Savings

	),
	



	/*********************************************************

		LOANS --Consider removing for above
		
	*********************************************************/

	--Initialize Loans information. Unique on ParentAccount, LoanID
	InitLoansCTE AS (

		SELECT
			ParentAccount AS 'LoanParentAccount'
			,Type AS 'LoanType'
			,ID AS 'LoanID'
			,DESCRIPTION AS 'LoanDescription'
			,OpenDate AS 'LoanOpenDate'
			,CloseDate AS 'LoanCloseDate'
			,PAYMENTCOUNT AS 'LoanTerm'
			,PAYMENTHISTORY1 AS 'LoanPaymentsMade'
		FROM
			SymitarExtracts.dbo.Loan

	),


	/****************
		Loan Tracking
	*****************/

		/* BEGIN Unique Loan Tracking */
		
			UniqueLoanTrackingCTE AS (
				
				SELECT 
					ParentAccount
					,ParentID
					,type
					,locator
					,MAX(locator) OVER (PARTITION BY parentaccount, parentid, Type) AS 'MaxLocator'
				FROM
					SymitarExtracts.dbo.LOANTRACKING
			
			),

		/* END Unique Tracking */


		--Initialize LoanTracking Information. Unique on parentaccount, loan id, tracking type
		InitLoanTrackingsCTE AS (

			SELECT
				'Loan' AS 'LoanTrackingType'
				,LoanTracking.ParentAccount AS 'LoanTrackingParentAccount'
				,LoanTracking.ParentID AS 'LoanTrackingParentID'
				,LoanTracking.type AS 'LoanTrackingNumber'
				,TrackingRecordTypes.description AS 'LoanTrackingTypeDescription'
				,LoanTracking.Ordinal AS 'LoanTrackingOrdinal'
				,LoanTracking.CreationDate AS 'LoanTrackingCreationDate'
				,LoanTracking.CreationTime AS 'LoanTrackingCreationTime'
				,LoanTracking.ExpireDate AS 'LoanTrackingExpirationDate'
				,LoanTracking.FMLASTDATE AS 'LoanTrackingLastFMDate'
				,LoanTracking.RecordChangeDate AS 'LoanTrackingRecordChangeDate'
				,UserNumber1 AS 'LoanTrackingUserNumber1'
				,UserNumber2 AS 'LoanTrackingUserNumber2'
				,UserNumber3 AS 'LoanTrackingUserNumber3'
				,UserNumber4 AS 'LoanTrackingUserNumber4'
				,UserNumber5 AS 'LoanTrackingUserNumber5'
				,UserNumber6 AS 'LoanTrackingUserNumber6'
				,UserNumber7 AS 'LoanTrackingUserNumber7'
				,UserNumber8 AS 'LoanTrackingUserNumber8'
				,UserNumber9 AS 'LoanTrackingUserNumber9'
				,UserNumber10 AS 'LoanTrackingUserNumber10'
				,Usernumber11 AS 'LoanTrackingUsernumber11'
				,Usernumber12 AS 'LoanTrackingUsernumber12'
				,Usernumber13 AS 'LoanTrackingUsernumber13'
				,Usernumber14 AS 'LoanTrackingUsernumber14'
				,Usernumber15 AS 'LoanTrackingUsernumber15'
				,Usernumber16 AS 'LoanTrackingUsernumber16'
				,Usernumber17 AS 'LoanTrackingUsernumber17'
				,Usernumber18 AS 'LoanTrackingUsernumber18'
				,Usernumber19 AS 'LoanTrackingUsernumber19'
				,Usernumber20 AS 'LoanTrackingUsernumber20'

				,UserChar1 AS 'LoanTrackingUserChar1'
				,UserChar2 AS 'LoanTrackingUserChar2'
				,UserChar3 AS 'LoanTrackingUserChar3'
				,UserChar4 AS 'LoanTrackingUserChar4'
				,UserChar5 AS 'LoanTrackingUserChar5'
				,UserChar6 AS 'LoanTrackingUserChar6'
				,UserChar7 AS 'LoanTrackingUserChar7'
				,UserChar8 AS 'LoanTrackingUserChar8'
				,UserChar9 AS 'LoanTrackingUserChar9'
				,UserChar10 AS 'LoanTrackingUserChar10'
				,UserChar11 AS 'LoanTrackingUserChar11'
				,UserChar12 AS 'LoanTrackingUserChar12'
				,UserChar13 AS 'LoanTrackingUserChar13'
				,UserChar14 AS 'LoanTrackingUserChar14'
				,UserChar15 AS 'LoanTrackingUserChar15'
				,UserChar16 AS 'LoanTrackingUserChar16'
				,UserChar17 AS 'LoanTrackingUserChar17'
				,UserChar18 AS 'LoanTrackingUserChar18'
				,UserChar19 AS 'LoanTrackingUserChar19'
				,UserChar20 AS 'LoanTrackingUserChar20'
      
				,UserAmount1 AS 'LoanTrackingUserAmount1'
				,UserAmount2 AS 'LoanTrackingUserAmount2'
				,UserAmount3 AS 'LoanTrackingUserAmount3'
				,UserAmount4 AS 'LoanTrackingUserAmount4'
				,UserAmount5 AS 'LoanTrackingUserAmount5'
				,UserAmount6 AS 'LoanTrackingUserAmount6'
				,UserAmount7 AS 'LoanTrackingUserAmount7'
				,UserAmount8 AS 'LoanTrackingUserAmount8'
				,UserAmount9 AS 'LoanTrackingUserAmount9'
				,UserAmount10 AS 'LoanTrackingUserAmount10'
				,UserAmount11 AS 'LoanTrackingUserAmount11'
				,UserAmount12 AS 'LoanTrackingUserAmount12'
				,UserAmount13 AS 'LoanTrackingUserAmount13'
				,UserAmount14 AS 'LoanTrackingUserAmount14'
				,UserAmount15 AS 'LoanTrackingUserAmount15'
				,UserAmount16 AS 'LoanTrackingUserAmount16'
				,UserAmount17 AS 'LoanTrackingUserAmount17'
				,UserAmount18 AS 'LoanTrackingUserAmount18'
				,UserAmount19 AS 'LoanTrackingUserAmount19'
				,UserAmount20 AS 'LoanTrackingUserAmount20'
     
				,Usercode1 AS 'LoanTrackingUsercode1'
				,Usercode2 AS 'LoanTrackingUsercode2'
				,Usercode3 AS 'LoanTrackingUsercode3'
				,Usercode4 AS 'LoanTrackingUsercode4'
				,Usercode5 AS 'LoanTrackingUsercode5'
				,Usercode6 AS 'LoanTrackingUsercode6'
				,Usercode7 AS 'LoanTrackingUsercode7'
				,Usercode8 AS 'LoanTrackingUsercode8'
				,Usercode9 AS 'LoanTrackingUsercode9'
				,Usercode10 AS 'LoanTrackingUsercode10'
				,UserCode11 AS 'LoanTrackingUsercode11'
				,UserCode12 AS 'LoanTrackingUsercode12'
				,UserCode13 AS 'LoanTrackingUsercode13'
				,UserCode14 AS 'LoanTrackingUsercode14'
				,UserCode15 AS 'LoanTrackingUsercode15'
				,UserCode16 AS 'LoanTrackingUsercode16'
				,UserCode17 AS 'LoanTrackingUsercode17'
				,UserCode18 AS 'LoanTrackingUsercode18'
				,UserCode19 AS 'LoanTrackingUsercode19'
				,UserCode20 AS 'LoanTrackingUsercode20'
      
				,UserDate1 AS 'LoanTrackingUserDate1'
				,UserDate2 AS 'LoanTrackingUserDate2'
				,UserDate3 AS 'LoanTrackingUserDate3'
				,UserDate4 AS 'LoanTrackingUserDate4'
				,UserDate5 AS 'LoanTrackingUserDate5'
				,UserDate6 AS 'LoanTrackingUserDate6'
				,UserDate7 AS 'LoanTrackingUserDate7'
				,UserDate8 AS 'LoanTrackingUserDate8'
				,UserDate9 AS 'LoanTrackingUserDate9'
				,UserDate10 AS 'LoanTrackingUserDate10'
				,UserDate11 AS 'LoanTrackingUserDate11'
				,UserDate12 AS 'LoanTrackingUserDate12'
				,UserDate13 AS 'LoanTrackingUserDate13'
				,UserDate14 AS 'LoanTrackingUserDate14'
				,UserDate15 AS 'LoanTrackingUserDate15'
				,UserDate16 AS 'LoanTrackingUserDate16'
				,UserDate17 AS 'LoanTrackingUserDate17'
				,UserDate18 AS 'LoanTrackingUserDate18'
				,UserDate19 AS 'LoanTrackingUserDate19'
				,UserDate20 AS 'LoanTrackingUserDate20'

				,UserRate1 AS 'LoanTrackingUserRate1'
				,UserRate2 AS 'LoanTrackingUserRate2'
				,UserRate3 AS 'LoanTrackingUserRate3'
				,UserRate4 AS 'LoanTrackingUserRate4'
				,UserRate5 AS 'LoanTrackingUserRate5'
				,UserRate6 AS 'LoanTrackingUserRate6'
				,UserRate7 AS 'LoanTrackingUserRate7'
				,UserRate8 AS 'LoanTrackingUserRate8'
				,UserRate9 AS 'LoanTrackingUserRate9'
				,UserRate10 AS 'LoanTrackingUserRate10'
				,UserRate11 AS 'LoanTrackingUserRate11'
				,UserRate12 AS 'LoanTrackingUserRate12'
				,UserRate13 AS 'LoanTrackingUserRate13'
				,UserRate14 AS 'LoanTrackingUserRate14'
				,UserRate15 AS 'LoanTrackingUserRate15'
				,UserRate16 AS 'LoanTrackingUserRate16'
				,UserRate17 AS 'LoanTrackingUserRate17'
				,UserRate18 AS 'LoanTrackingUserRate18'
				,UserRate19 AS 'LoanTrackingUserRate19'
				,UserRate20 AS 'LoanTrackingUserRate20'
			FROM
				SymitarExtracts.dbo.LOANTRACKING
				JOIN UniqueLoanTrackingCTE
					ON	LoanTracking.ParentAccount = UniqueLoanTrackingCTE.ParentAccount 
						AND LoanTracking.ParentID = UniqueLoanTrackingCTE.ParentID 
						AND LoanTracking.Type = UniqueLoanTrackingCTE.TYPE
						AND UniqueLoanTrackingCTE.MaxLocator = UniqueLoanTrackingCTE.Locator
				LEFT OUTER JOIN SymitarParameters.dbo.TrackingRecordTypes
					ON	LoanTracking.type = TrackingRecordTypes.number
						AND TrackingRecordTypes.level = 'LOAN'

		),







	/*********************************************************

		Trackings
		
	*********************************************************/


		UniqueTrackingCTE AS (
				
				SELECT
					'Account' AS 'TrackingLevel'
					,ParentAccount
					,ID AS 'ParentID'
					,type
					,locator
					,MAX(locator) OVER (PARTITION BY parentaccount, ID, Type) AS 'MaxLocator'
				FROM
					SymitarExtracts.dbo.Tracking
				WHERE
					@Lens LIKE '%AccountTrackings%'
					
				
				UNION
				
				
				SELECT
					'Share' AS 'TrackingLevel' 
					,ParentAccount
					,ParentID
					,type
					,locator
					,MAX(locator) OVER (PARTITION BY parentaccount, parentid, Type) AS 'MaxLocator'
				FROM
					SymitarExtracts.dbo.SAVINGSTRACKING
				WHERE
					@Lens LIKE '%ShareTrackings%'

				
				UNION
			

				SELECT
					'Loan' AS 'TrackingLevel' 
					,ParentAccount
					,ParentID
					,type
					,locator
					,MAX(locator) OVER (PARTITION BY parentaccount, parentid, Type) AS 'MaxLocator'
				FROM
					SymitarExtracts.dbo.LOANTRACKING
				WHERE
					@Lens LIKE '%LoanTrackings%'
			),



		--Initialize LoanTracking Information. Unique on parentaccount, loan id, tracking type
		InitTrackingsCTE AS (
		
			SELECT
				'Account' AS 'TrackingType'
				,Tracking.ParentAccount AS 'TrackingParentAccount'
				,Tracking.ID AS 'TrackingParentID'
				,Tracking.type AS 'TrackingNumber'
				,TrackingRecordTypes.description AS 'TrackingTypeDescription'
				,Tracking.Ordinal AS 'TrackingOrdinal'
				,Tracking.CreationDate AS 'TrackingCreationDate'
				,Tracking.CreationTime AS 'TrackingCreationTime'
				,Tracking.ExpireDate AS 'TrackingExpirationDate'
				,Tracking.FMLASTDATE AS 'TrackingLastFMDate'
				,Tracking.RecordChangeDate AS 'TrackingRecordChangeDate'
				,UserNumber1 AS 'TrackingUserNumber1'
				,UserNumber2 AS 'TrackingUserNumber2'
				,UserNumber3 AS 'TrackingUserNumber3'
				,UserNumber4 AS 'TrackingUserNumber4'
				,UserNumber5 AS 'TrackingUserNumber5'
				,UserNumber6 AS 'TrackingUserNumber6'
				,UserNumber7 AS 'TrackingUserNumber7'
				,UserNumber8 AS 'TrackingUserNumber8'
				,UserNumber9 AS 'TrackingUserNumber9'
				,UserNumber10 AS 'TrackingUserNumber10'
				,Usernumber11 AS 'TrackingUsernumber11'
				,Usernumber12 AS 'TrackingUsernumber12'
				,Usernumber13 AS 'TrackingUsernumber13'
				,Usernumber14 AS 'TrackingUsernumber14'
				,Usernumber15 AS 'TrackingUsernumber15'
				,Usernumber16 AS 'TrackingUsernumber16'
				,Usernumber17 AS 'TrackingUsernumber17'
				,Usernumber18 AS 'TrackingUsernumber18'
				,Usernumber19 AS 'TrackingUsernumber19'
				,Usernumber20 AS 'TrackingUsernumber20'

				,UserChar1 AS 'TrackingUserChar1'
				,UserChar2 AS 'TrackingUserChar2'
				,UserChar3 AS 'TrackingUserChar3'
				,UserChar4 AS 'TrackingUserChar4'
				,UserChar5 AS 'TrackingUserChar5'
				,UserChar6 AS 'TrackingUserChar6'
				,UserChar7 AS 'TrackingUserChar7'
				,UserChar8 AS 'TrackingUserChar8'
				,UserChar9 AS 'TrackingUserChar9'
				,UserChar10 AS 'TrackingUserChar10'
				,UserChar11 AS 'TrackingUserChar11'
				,UserChar12 AS 'TrackingUserChar12'
				,UserChar13 AS 'TrackingUserChar13'
				,UserChar14 AS 'TrackingUserChar14'
				,UserChar15 AS 'TrackingUserChar15'
				,UserChar16 AS 'TrackingUserChar16'
				,UserChar17 AS 'TrackingUserChar17'
				,UserChar18 AS 'TrackingUserChar18'
				,UserChar19 AS 'TrackingUserChar19'
				,UserChar20 AS 'TrackingUserChar20'
      
				,UserAmount1 AS 'TrackingUserAmount1'
				,UserAmount2 AS 'TrackingUserAmount2'
				,UserAmount3 AS 'TrackingUserAmount3'
				,UserAmount4 AS 'TrackingUserAmount4'
				,UserAmount5 AS 'TrackingUserAmount5'
				,UserAmount6 AS 'TrackingUserAmount6'
				,UserAmount7 AS 'TrackingUserAmount7'
				,UserAmount8 AS 'TrackingUserAmount8'
				,UserAmount9 AS 'TrackingUserAmount9'
				,UserAmount10 AS 'TrackingUserAmount10'
				,UserAmount11 AS 'TrackingUserAmount11'
				,UserAmount12 AS 'TrackingUserAmount12'
				,UserAmount13 AS 'TrackingUserAmount13'
				,UserAmount14 AS 'TrackingUserAmount14'
				,UserAmount15 AS 'TrackingUserAmount15'
				,UserAmount16 AS 'TrackingUserAmount16'
				,UserAmount17 AS 'TrackingUserAmount17'
				,UserAmount18 AS 'TrackingUserAmount18'
				,UserAmount19 AS 'TrackingUserAmount19'
				,UserAmount20 AS 'TrackingUserAmount20'
     
				,Usercode1 AS 'TrackingUsercode1'
				,Usercode2 AS 'TrackingUsercode2'
				,Usercode3 AS 'TrackingUsercode3'
				,Usercode4 AS 'TrackingUsercode4'
				,Usercode5 AS 'TrackingUsercode5'
				,Usercode6 AS 'TrackingUsercode6'
				,Usercode7 AS 'TrackingUsercode7'
				,Usercode8 AS 'TrackingUsercode8'
				,Usercode9 AS 'TrackingUsercode9'
				,Usercode10 AS 'TrackingUsercode10'
				,UserCode11 AS 'TrackingUsercode11'
				,UserCode12 AS 'TrackingUsercode12'
				,UserCode13 AS 'TrackingUsercode13'
				,UserCode14 AS 'TrackingUsercode14'
				,UserCode15 AS 'TrackingUsercode15'
				,UserCode16 AS 'TrackingUsercode16'
				,UserCode17 AS 'TrackingUsercode17'
				,UserCode18 AS 'TrackingUsercode18'
				,UserCode19 AS 'TrackingUsercode19'
				,UserCode20 AS 'TrackingUsercode20'
      
				,UserDate1 AS 'TrackingUserDate1'
				,UserDate2 AS 'TrackingUserDate2'
				,UserDate3 AS 'TrackingUserDate3'
				,UserDate4 AS 'TrackingUserDate4'
				,UserDate5 AS 'TrackingUserDate5'
				,UserDate6 AS 'TrackingUserDate6'
				,UserDate7 AS 'TrackingUserDate7'
				,UserDate8 AS 'TrackingUserDate8'
				,UserDate9 AS 'TrackingUserDate9'
				,UserDate10 AS 'TrackingUserDate10'
				,UserDate11 AS 'TrackingUserDate11'
				,UserDate12 AS 'TrackingUserDate12'
				,UserDate13 AS 'TrackingUserDate13'
				,UserDate14 AS 'TrackingUserDate14'
				,UserDate15 AS 'TrackingUserDate15'
				,UserDate16 AS 'TrackingUserDate16'
				,UserDate17 AS 'TrackingUserDate17'
				,UserDate18 AS 'TrackingUserDate18'
				,UserDate19 AS 'TrackingUserDate19'
				,UserDate20 AS 'TrackingUserDate20'

				,UserRate1 AS 'TrackingUserRate1'
				,UserRate2 AS 'TrackingUserRate2'
				,UserRate3 AS 'TrackingUserRate3'
				,UserRate4 AS 'TrackingUserRate4'
				,UserRate5 AS 'TrackingUserRate5'
				,UserRate6 AS 'TrackingUserRate6'
				,UserRate7 AS 'TrackingUserRate7'
				,UserRate8 AS 'TrackingUserRate8'
				,UserRate9 AS 'TrackingUserRate9'
				,UserRate10 AS 'TrackingUserRate10'
				,UserRate11 AS 'TrackingUserRate11'
				,UserRate12 AS 'TrackingUserRate12'
				,UserRate13 AS 'TrackingUserRate13'
				,UserRate14 AS 'TrackingUserRate14'
				,UserRate15 AS 'TrackingUserRate15'
				,UserRate16 AS 'TrackingUserRate16'
				,UserRate17 AS 'TrackingUserRate17'
				,UserRate18 AS 'TrackingUserRate18'
				,UserRate19 AS 'TrackingUserRate19'
				,UserRate20 AS 'TrackingUserRate20'
			FROM
				SymitarExtracts.dbo.Tracking
				JOIN UniqueTrackingCTE
					ON	Tracking.ParentAccount = UniqueTrackingCTE.ParentAccount 
						AND Tracking.Type = UniqueTrackingCTE.TYPE
						AND UniqueTrackingCTE.MaxLocator = UniqueTrackingCTE.Locator
						AND UniqueTrackingCTE.TrackingLevel = 'ACCOUNT'
				LEFT OUTER JOIN SymitarParameters.dbo.TrackingRecordTypes
					ON	Tracking.type = TrackingRecordTypes.number
						AND TrackingRecordTypes.level = 'ACCOUNT'
			WHERE
				@Lens LIKE '%AccountTrackings%'


				UNION


				
			SELECT
				'Share' AS 'TrackingType'
				,SavingsTracking.ParentAccount AS 'SavingsTrackingParentAccount'
				,SavingsTracking.ParentID AS 'SavingsTrackingParentID'
				,SavingsTracking.type AS 'SavingsnTrackingNumber'
				,TrackingRecordTypes.description AS 'SavingsTrackingTypeDescription'
				,SavingsTracking.Ordinal AS 'SavingsTrackingOrdinal'
				,SavingsTracking.CreationDate AS 'SavingsTrackingCreationDate'
				,SavingsTracking.CreationTime AS 'SavingsTrackingCreationTime'
				,SavingsTracking.ExpireDate AS 'SavingsTrackingExpirationDate'
				,SavingsTracking.FMLASTDATE AS 'SavingsTrackingLastFMDate'
				,SavingsTracking.RecordChangeDate AS 'SavingsTrackingRecordChangeDate'
				,UserNumber1 AS 'TrackingUserNumber1'
				,UserNumber2 AS 'TrackingUserNumber2'
				,UserNumber3 AS 'TrackingUserNumber3'
				,UserNumber4 AS 'TrackingUserNumber4'
				,UserNumber5 AS 'TrackingUserNumber5'
				,UserNumber6 AS 'TrackingUserNumber6'
				,UserNumber7 AS 'TrackingUserNumber7'
				,UserNumber8 AS 'TrackingUserNumber8'
				,UserNumber9 AS 'TrackingUserNumber9'
				,UserNumber10 AS 'TrackingUserNumber10'
				,Usernumber11 AS 'TrackingUsernumber11'
				,Usernumber12 AS 'TrackingUsernumber12'
				,Usernumber13 AS 'TrackingUsernumber13'
				,Usernumber14 AS 'TrackingUsernumber14'
				,Usernumber15 AS 'TrackingUsernumber15'
				,Usernumber16 AS 'TrackingUsernumber16'
				,Usernumber17 AS 'TrackingUsernumber17'
				,Usernumber18 AS 'TrackingUsernumber18'
				,Usernumber19 AS 'TrackingUsernumber19'
				,Usernumber20 AS 'TrackingUsernumber20'

				,UserChar1 AS 'TrackingUserChar1'
				,UserChar2 AS 'TrackingUserChar2'
				,UserChar3 AS 'TrackingUserChar3'
				,UserChar4 AS 'TrackingUserChar4'
				,UserChar5 AS 'TrackingUserChar5'
				,UserChar6 AS 'TrackingUserChar6'
				,UserChar7 AS 'TrackingUserChar7'
				,UserChar8 AS 'TrackingUserChar8'
				,UserChar9 AS 'TrackingUserChar9'
				,UserChar10 AS 'TrackingUserChar10'
				,UserChar11 AS 'TrackingUserChar11'
				,UserChar12 AS 'TrackingUserChar12'
				,UserChar13 AS 'TrackingUserChar13'
				,UserChar14 AS 'TrackingUserChar14'
				,UserChar15 AS 'TrackingUserChar15'
				,UserChar16 AS 'TrackingUserChar16'
				,UserChar17 AS 'TrackingUserChar17'
				,UserChar18 AS 'TrackingUserChar18'
				,UserChar19 AS 'TrackingUserChar19'
				,UserChar20 AS 'TrackingUserChar20'
      
				,UserAmount1 AS 'TrackingUserAmount1'
				,UserAmount2 AS 'TrackingUserAmount2'
				,UserAmount3 AS 'TrackingUserAmount3'
				,UserAmount4 AS 'TrackingUserAmount4'
				,UserAmount5 AS 'TrackingUserAmount5'
				,UserAmount6 AS 'TrackingUserAmount6'
				,UserAmount7 AS 'TrackingUserAmount7'
				,UserAmount8 AS 'TrackingUserAmount8'
				,UserAmount9 AS 'TrackingUserAmount9'
				,UserAmount10 AS 'TrackingUserAmount10'
				,UserAmount11 AS 'TrackingUserAmount11'
				,UserAmount12 AS 'TrackingUserAmount12'
				,UserAmount13 AS 'TrackingUserAmount13'
				,UserAmount14 AS 'TrackingUserAmount14'
				,UserAmount15 AS 'TrackingUserAmount15'
				,UserAmount16 AS 'TrackingUserAmount16'
				,UserAmount17 AS 'TrackingUserAmount17'
				,UserAmount18 AS 'TrackingUserAmount18'
				,UserAmount19 AS 'TrackingUserAmount19'
				,UserAmount20 AS 'TrackingUserAmount20'
     
				,Usercode1 AS 'TrackingUsercode1'
				,Usercode2 AS 'TrackingUsercode2'
				,Usercode3 AS 'TrackingUsercode3'
				,Usercode4 AS 'TrackingUsercode4'
				,Usercode5 AS 'TrackingUsercode5'
				,Usercode6 AS 'TrackingUsercode6'
				,Usercode7 AS 'TrackingUsercode7'
				,Usercode8 AS 'TrackingUsercode8'
				,Usercode9 AS 'TrackingUsercode9'
				,Usercode10 AS 'TrackingUsercode10'
				,UserCode11 AS 'TrackingUsercode11'
				,UserCode12 AS 'TrackingUsercode12'
				,UserCode13 AS 'TrackingUsercode13'
				,UserCode14 AS 'TrackingUsercode14'
				,UserCode15 AS 'TrackingUsercode15'
				,UserCode16 AS 'TrackingUsercode16'
				,UserCode17 AS 'TrackingUsercode17'
				,UserCode18 AS 'TrackingUsercode18'
				,UserCode19 AS 'TrackingUsercode19'
				,UserCode20 AS 'TrackingUsercode20'
      
				,UserDate1 AS 'TrackingUserDate1'
				,UserDate2 AS 'TrackingUserDate2'
				,UserDate3 AS 'TrackingUserDate3'
				,UserDate4 AS 'TrackingUserDate4'
				,UserDate5 AS 'TrackingUserDate5'
				,UserDate6 AS 'TrackingUserDate6'
				,UserDate7 AS 'TrackingUserDate7'
				,UserDate8 AS 'TrackingUserDate8'
				,UserDate9 AS 'TrackingUserDate9'
				,UserDate10 AS 'TrackingUserDate10'
				,UserDate11 AS 'TrackingUserDate11'
				,UserDate12 AS 'TrackingUserDate12'
				,UserDate13 AS 'TrackingUserDate13'
				,UserDate14 AS 'TrackingUserDate14'
				,UserDate15 AS 'TrackingUserDate15'
				,UserDate16 AS 'TrackingUserDate16'
				,UserDate17 AS 'TrackingUserDate17'
				,UserDate18 AS 'TrackingUserDate18'
				,UserDate19 AS 'TrackingUserDate19'
				,UserDate20 AS 'TrackingUserDate20'

				,UserRate1 AS 'TrackingUserRate1'
				,UserRate2 AS 'TrackingUserRate2'
				,UserRate3 AS 'TrackingUserRate3'
				,UserRate4 AS 'TrackingUserRate4'
				,UserRate5 AS 'TrackingUserRate5'
				,UserRate6 AS 'TrackingUserRate6'
				,UserRate7 AS 'TrackingUserRate7'
				,UserRate8 AS 'TrackingUserRate8'
				,UserRate9 AS 'TrackingUserRate9'
				,UserRate10 AS 'TrackingUserRate10'
				,UserRate11 AS 'TrackingUserRate11'
				,UserRate12 AS 'TrackingUserRate12'
				,UserRate13 AS 'TrackingUserRate13'
				,UserRate14 AS 'TrackingUserRate14'
				,UserRate15 AS 'TrackingUserRate15'
				,UserRate16 AS 'TrackingUserRate16'
				,UserRate17 AS 'TrackingUserRate17'
				,UserRate18 AS 'TrackingUserRate18'
				,UserRate19 AS 'TrackingUserRate19'
				,UserRate20 AS 'TrackingUserRate20'
			FROM
				SymitarExtracts.dbo.SavingsTracking
				JOIN UniqueTrackingCTE
					ON	SavingsTracking.ParentAccount = UniqueTrackingCTE.ParentAccount 
						AND SavingsTracking.ParentID = UniqueTrackingCTE.ParentID 
						AND SavingsTracking.Type = UniqueTrackingCTE.TYPE
						AND UniqueTrackingCTE.MaxLocator = UniqueTrackingCTE.Locator
						AND UniqueTrackingCTE.TrackingLevel = 'Share'
				LEFT OUTER JOIN SymitarParameters.dbo.TrackingRecordTypes
					ON	SavingsTracking.type = TrackingRecordTypes.number
						AND TrackingRecordTypes.level = 'Share'

			WHERE
				@Lens LIKE '%ShareTrackings%'


			UNION


			SELECT
				'Loan' AS 'LoanTrackingType'
				,LoanTracking.ParentAccount AS 'LoanTrackingParentAccount'
				,LoanTracking.ParentID AS 'LoanTrackingParentID'
				,LoanTracking.type AS 'LoanTrackingNumber'
				,TrackingRecordTypes.description AS 'LoanTrackingTypeDescription'
				,LoanTracking.Ordinal AS 'LoanTrackingOrdinal'
				,LoanTracking.CreationDate AS 'LoanTrackingCreationDate'
				,LoanTracking.CreationTime AS 'LoanTrackingCreationTime'
				,LoanTracking.ExpireDate AS 'LoanTrackingExpirationDate'
				,LoanTracking.FMLASTDATE AS 'LoanTrackingLastFMDate'
				,LoanTracking.RecordChangeDate AS 'LoanTrackingRecordChangeDate'
				,UserNumber1 AS 'LoanTrackingUserNumber1'
				,UserNumber2 AS 'LoanTrackingUserNumber2'
				,UserNumber3 AS 'LoanTrackingUserNumber3'
				,UserNumber4 AS 'LoanTrackingUserNumber4'
				,UserNumber5 AS 'LoanTrackingUserNumber5'
				,UserNumber6 AS 'LoanTrackingUserNumber6'
				,UserNumber7 AS 'LoanTrackingUserNumber7'
				,UserNumber8 AS 'LoanTrackingUserNumber8'
				,UserNumber9 AS 'LoanTrackingUserNumber9'
				,UserNumber10 AS 'LoanTrackingUserNumber10'
				,Usernumber11 AS 'LoanTrackingUsernumber11'
				,Usernumber12 AS 'LoanTrackingUsernumber12'
				,Usernumber13 AS 'LoanTrackingUsernumber13'
				,Usernumber14 AS 'LoanTrackingUsernumber14'
				,Usernumber15 AS 'LoanTrackingUsernumber15'
				,Usernumber16 AS 'LoanTrackingUsernumber16'
				,Usernumber17 AS 'LoanTrackingUsernumber17'
				,Usernumber18 AS 'LoanTrackingUsernumber18'
				,Usernumber19 AS 'LoanTrackingUsernumber19'
				,Usernumber20 AS 'LoanTrackingUsernumber20'

				,UserChar1 AS 'LoanTrackingUserChar1'
				,UserChar2 AS 'LoanTrackingUserChar2'
				,UserChar3 AS 'LoanTrackingUserChar3'
				,UserChar4 AS 'LoanTrackingUserChar4'
				,UserChar5 AS 'LoanTrackingUserChar5'
				,UserChar6 AS 'LoanTrackingUserChar6'
				,UserChar7 AS 'LoanTrackingUserChar7'
				,UserChar8 AS 'LoanTrackingUserChar8'
				,UserChar9 AS 'LoanTrackingUserChar9'
				,UserChar10 AS 'LoanTrackingUserChar10'
				,UserChar11 AS 'LoanTrackingUserChar11'
				,UserChar12 AS 'LoanTrackingUserChar12'
				,UserChar13 AS 'LoanTrackingUserChar13'
				,UserChar14 AS 'LoanTrackingUserChar14'
				,UserChar15 AS 'LoanTrackingUserChar15'
				,UserChar16 AS 'LoanTrackingUserChar16'
				,UserChar17 AS 'LoanTrackingUserChar17'
				,UserChar18 AS 'LoanTrackingUserChar18'
				,UserChar19 AS 'LoanTrackingUserChar19'
				,UserChar20 AS 'LoanTrackingUserChar20'
      
				,UserAmount1 AS 'LoanTrackingUserAmount1'
				,UserAmount2 AS 'LoanTrackingUserAmount2'
				,UserAmount3 AS 'LoanTrackingUserAmount3'
				,UserAmount4 AS 'LoanTrackingUserAmount4'
				,UserAmount5 AS 'LoanTrackingUserAmount5'
				,UserAmount6 AS 'LoanTrackingUserAmount6'
				,UserAmount7 AS 'LoanTrackingUserAmount7'
				,UserAmount8 AS 'LoanTrackingUserAmount8'
				,UserAmount9 AS 'LoanTrackingUserAmount9'
				,UserAmount10 AS 'LoanTrackingUserAmount10'
				,UserAmount11 AS 'LoanTrackingUserAmount11'
				,UserAmount12 AS 'LoanTrackingUserAmount12'
				,UserAmount13 AS 'LoanTrackingUserAmount13'
				,UserAmount14 AS 'LoanTrackingUserAmount14'
				,UserAmount15 AS 'LoanTrackingUserAmount15'
				,UserAmount16 AS 'LoanTrackingUserAmount16'
				,UserAmount17 AS 'LoanTrackingUserAmount17'
				,UserAmount18 AS 'LoanTrackingUserAmount18'
				,UserAmount19 AS 'LoanTrackingUserAmount19'
				,UserAmount20 AS 'LoanTrackingUserAmount20'
     
				,Usercode1 AS 'LoanTrackingUsercode1'
				,Usercode2 AS 'LoanTrackingUsercode2'
				,Usercode3 AS 'LoanTrackingUsercode3'
				,Usercode4 AS 'LoanTrackingUsercode4'
				,Usercode5 AS 'LoanTrackingUsercode5'
				,Usercode6 AS 'LoanTrackingUsercode6'
				,Usercode7 AS 'LoanTrackingUsercode7'
				,Usercode8 AS 'LoanTrackingUsercode8'
				,Usercode9 AS 'LoanTrackingUsercode9'
				,Usercode10 AS 'LoanTrackingUsercode10'
				,UserCode11 AS 'LoanTrackingUsercode11'
				,UserCode12 AS 'LoanTrackingUsercode12'
				,UserCode13 AS 'LoanTrackingUsercode13'
				,UserCode14 AS 'LoanTrackingUsercode14'
				,UserCode15 AS 'LoanTrackingUsercode15'
				,UserCode16 AS 'LoanTrackingUsercode16'
				,UserCode17 AS 'LoanTrackingUsercode17'
				,UserCode18 AS 'LoanTrackingUsercode18'
				,UserCode19 AS 'LoanTrackingUsercode19'
				,UserCode20 AS 'LoanTrackingUsercode20'
      
				,UserDate1 AS 'LoanTrackingUserDate1'
				,UserDate2 AS 'LoanTrackingUserDate2'
				,UserDate3 AS 'LoanTrackingUserDate3'
				,UserDate4 AS 'LoanTrackingUserDate4'
				,UserDate5 AS 'LoanTrackingUserDate5'
				,UserDate6 AS 'LoanTrackingUserDate6'
				,UserDate7 AS 'LoanTrackingUserDate7'
				,UserDate8 AS 'LoanTrackingUserDate8'
				,UserDate9 AS 'LoanTrackingUserDate9'
				,UserDate10 AS 'LoanTrackingUserDate10'
				,UserDate11 AS 'LoanTrackingUserDate11'
				,UserDate12 AS 'LoanTrackingUserDate12'
				,UserDate13 AS 'LoanTrackingUserDate13'
				,UserDate14 AS 'LoanTrackingUserDate14'
				,UserDate15 AS 'LoanTrackingUserDate15'
				,UserDate16 AS 'LoanTrackingUserDate16'
				,UserDate17 AS 'LoanTrackingUserDate17'
				,UserDate18 AS 'LoanTrackingUserDate18'
				,UserDate19 AS 'LoanTrackingUserDate19'
				,UserDate20 AS 'LoanTrackingUserDate20'

				,UserRate1 AS 'LoanTrackingUserRate1'
				,UserRate2 AS 'LoanTrackingUserRate2'
				,UserRate3 AS 'LoanTrackingUserRate3'
				,UserRate4 AS 'LoanTrackingUserRate4'
				,UserRate5 AS 'LoanTrackingUserRate5'
				,UserRate6 AS 'LoanTrackingUserRate6'
				,UserRate7 AS 'LoanTrackingUserRate7'
				,UserRate8 AS 'LoanTrackingUserRate8'
				,UserRate9 AS 'LoanTrackingUserRate9'
				,UserRate10 AS 'LoanTrackingUserRate10'
				,UserRate11 AS 'LoanTrackingUserRate11'
				,UserRate12 AS 'LoanTrackingUserRate12'
				,UserRate13 AS 'LoanTrackingUserRate13'
				,UserRate14 AS 'LoanTrackingUserRate14'
				,UserRate15 AS 'LoanTrackingUserRate15'
				,UserRate16 AS 'LoanTrackingUserRate16'
				,UserRate17 AS 'LoanTrackingUserRate17'
				,UserRate18 AS 'LoanTrackingUserRate18'
				,UserRate19 AS 'LoanTrackingUserRate19'
				,UserRate20 AS 'LoanTrackingUserRate20'
			FROM
				SymitarExtracts.dbo.LOANTRACKING
				JOIN UniqueTrackingCTE
					ON	LoanTracking.ParentAccount = UniqueTrackingCTE.ParentAccount 
						AND LoanTracking.ParentID = UniqueTrackingCTE.ParentID 
						AND LoanTracking.Type = UniqueTrackingCTE.TYPE
						AND UniqueTrackingCTE.MaxLocator = UniqueTrackingCTE.Locator
						AND UniqueTrackingCTE.TrackingLevel = 'LOAN'
				LEFT OUTER JOIN SymitarParameters.dbo.TrackingRecordTypes
					ON	LoanTracking.type = TrackingRecordTypes.number
						AND TrackingRecordTypes.level = 'LOAN'
			WHERE
				@Lens LIKE '%LoanTrackings%'

		),


	EMPTYCTE AS (SELECT NULL AS 'Empty')
	--:ENDBODY--

	
	--:BEGINMAINQUERY--
	/*********************************************************
		Start of main output query
	*********************************************************/
	

	SELECT DISTINCT
		*
	FROM
		--Member Account and Name Information
		InitMembersCTE

		
		LEFT OUTER JOIN InitMemberContactsCTE --**Not Validated
			ON (@Lens LIKE '%:Members/Contacts/%') 
				AND InitMembersCTE.ACCOUNTNUMBER = InitMemberContactsCTE.ContactParentAccount
		

		
		LEFT OUTER JOIN InitMembersNameTypesCTE --**Not Validated
			ON	(@Lens LIKE '%:Members/Names/%')
				AND InitMembersCTE.AccountNumber = InitMembersNameTypesCTE.NameTypeParentAccount

			
			LEFT OUTER JOIN  --**Not Validated
				InitMembersGISLocationCTE
				ON	(@Lens LIKE '%:Members/Names/GISLocations/%')
					AND InitMembersGISLocationCTE.GISParentAccount = InitMembersNameTypesCTE.NameTypeParentAccount
					AND InitMembersGISLocationCTE.GISNameType = InitMembersNameTypesCTE.NameType		
			
			LEFT OUTER JOIN FlagSSNChargeOffCTE --**Not Validated
				ON	(@Lens LIKE '%:Members/Names/ChargeOffs/%')
					AND InitMembersNameTypesCTE.NameTypeSSN = FlagSSNChargeOffCTE. ChargeOffSSN
			
			LEFT OUTER JOIN FlagSSNOpenPromoCTE --**Not Validated
				ON	(@Lens LIKE '%:Members/Names/OpenPromos/%')
					AND InitMembersNameTypesCTE.NameTypeSSN = FlagSSNOpenPromoCTE.OpenPromoSSN
			
			LEFT OUTER JOIN SSNUnsecuredBalanceCTE --**Not Validated
				ON (@Lens LIKE '%:Members/Names/UnsecuredBalances/%')
					AND InitMembersNameTypesCTE.NameTypeSSN = SSNUnsecuredBalanceCTE.UnsecuredBalanceSSN
			
			LEFT OUTER JOIN FlagSSNLoanModCTE --**Not Validated
				ON (@Lens LIKE '%:Members/Names/LoanModifications/%')
					AND InitMembersNameTypesCTE.NameTypeSSN = FlagSSNLoanModCTE.LoanModSSN
			
			LEFT OUTER JOIN FlagSSNLoanDenialCTE --**Not Validated
				ON (@Lens LIKE '%:Members/Names/LoanDenials/%')
					AND InitMembersNameTypesCTE.NameTypeSSN = FlagSSNLoanDenialCTE.LoanDenialSSN
		


		
		
		LEFT OUTER JOIN InitProductsCTE --Member Products Information (Shares and Loans) --**Not Validated
			ON (@Lens LIKE '%:Members/Products/%')
				AND InitMembersCTE.AccountNumber = InitProductsCTE.ProductParentAccount

			LEFT OUTER JOIN InitTransactionsCTE	--All products transactions --**Not Validated
				ON (@Lens LIKE '%:Members/Products/Transactions/%')
					AND InitProductsCTE.ProductParentAccount = InitTransactionsCTE.TransactionParentAccount 
					AND InitProductsCTE.ProductID = InitTransactionsCTE.TransactionParentID
					AND InitProductsCTE.ProductType = InitTransactionsCTE.TransactionType
		
			
			
			LEFT OUTER JOIN InitLoanTrackingsCTE  --Member Loan Information  --**Not Validated
				ON	(@Lens LIKE '%:Members/Products/LoanTrackings/%')
					AND InitProductsCTE.ProductParentAccount = InitLoanTrackingsCTE.LoanTrackingParentAccount
					AND InitProductsCTE.ProductID = InitLoanTrackingsCTE.LoanTrackingParentID
					AND InitProductsCTE.ProductType = InitLoanTrackingsCTE.LoanTrackingType
			












		--:ENDMAINQUERY--

		--:BEGINTESTS--
		
		--LEFT OUTER JOIN InitSharesCTE
		--	ON	(@Lens LIKE '%:Shares/%')
		--		AND InitMembersCTE.AccountNumber = InitSharesCTE.ShareParentAccount 
		--LEFT OUTER JOIN InitLoansCTE
		--	ON	(@Lens LIKE '%:Loans/%')
		--		AND InitMembersCTE.AccountNumber = InitLoansCTE.LoanParentAccount
		--LEFT OUTER JOIN InitLoanTrackingsCTE
		--	ON	(@Lens LIKE '%:Loans/Trackings/%')
		--		AND InitLoansCTE.LoanParentAccount = InitLoanTrackingsCTE.LoanTrackingParentAccount
		--		AND InitLoansCTE.LoanID = InitLoanTrackingsCTE.LoanTrackingParentID
		--LEFT OUTER JOIN InitLoanTransactionsCTE
		--	ON	(@Lens LIKE '%:Loans/Transactions/%')
		--		AND InitLoansCTE.LoanParentAccount = InitLoanTransactionsCTE.LoanTransactionParentAccount 
		--		AND InitLoansCTE.LoanID = InitLoanTransactionsCTE.LoanTransactionParentID





		----Alternative way is more efficient TrackingRecords
		----**Not Validated
		--LEFT OUTER JOIN InitTrackingsCTE
		--	ON	(@Lens LIKE '%:Members/AccountTrackings/%' 
		--			AND InitMembersCTE.AccountNumber = InitTrackingsCTE.TrackingParentAccount)
		--		OR (@Lens LIKE '%:Members/Products/ShareTrackings/%'
		--				AND InitProductsCTE.ProductParentAccount = InitTrackingsCTE.TrackingParentAccount
		--				AND InitProductsCTE.ProductID = InitTrackingsCTE.TrackingParentID
		--				AND InitProductsCTE.ProductType = InitTrackingsCTE.TrackingType)
		--		OR (@Lens LIKE '%:Members/Products/LoanTrackings/%'
		--				AND InitProductsCTE.ProductParentAccount = InitTrackingsCTE.TrackingParentAccount
		--				AND InitProductsCTE.ProductID = InitTrackingsCTE.TrackingParentID
		--				AND InitProductsCTE.ProductType = InitTrackingsCTE.TrackingType)


	/*********************************************************

		TRANSACTIONS - Not Optimzed for use yet
		
	*********************************************************/

/*
	TellerTransactionsCTE AS (
	
		SELECT
			TellerXActionDetailR2.DetailRecID AS 'TransactionRecordID'
			,Account.AccountNumber AS 'TransactionParentAccount'
			,CASE	WHEN Account.AccountNumber IS NULL
					THEN NULL
					ELSE RIGHT(RTRIM(Account),2)
			END AS 'TransactionAccountID'
			,TellerXActionDetailR2.XActionDate AS 'TransactionDateTime'
			,CONVERT(DATE,XActionDate) AS 'TransactionDate'
			,CONVERT(TIME, XActionDate) AS 'TransactionTime'
			,ROW_NUMBER() OVER (PARTITION BY XActionDate, TellerID, XActionAmt ORDER BY XActionDate, SequenceNbr, DetailRecID) AS 'TransactionAmountRowNumber'	--Identify transaction instances done by a TM in the same minute, on the same day
			,ROW_NUMBER() OVER (PARTITION BY XActionDate, TellerID, SequenceNbr ORDER BY XActionDate, SequenceNbr, DetailRecID) AS 'TransactionSequenceRowNumber'		--Identify trnasaction instances done by TM on the same day, under the same sequence number
			,TellerXActionDetailR2.SequenceNbr AS 'TransactionSequenceNumber'
			,TellerXActionDetailR2.BranchID AS 'TransactionBranchID'
			,TellerXActionDetailR2.TellerID AS 'TransactionTellerID'
			,TellerXActionDetailR2.Status AS 'TransactionStatus'
			,TellerXActionDetailR2.Descrip AS 'TransactionDescription'
			,TellerXActionDetailR2.XactionAmt AS 'TransactionAmount'
			,TellerXActionDetailR2.XActionType AS 'TransactionType'
			,TellerXActionDetailR2.Account AS 'TransactionAccount'
		
		FROM 
			ACNetSQLSVR01.TellerMgmt.dbo.TellerXActionDetailR2
			LEFT OUTER JOIN SymitarExtracts.dbo.Account
				ON LEFT(TellerXActionDetailR2.Account, 10) = Account.AccountNumber
		WHERE 
			  ( ( (@StartDate IS NULL OR @EndDate IS NULL) AND XActionDate > '1900-01-01' ) 
					OR (XActionDate BETWEEN @StartDate AND @EndDate) )
			  -- AND Descrip <> 'Loan Interest' AND Descrip <> 'Loan Principal Payment'	--Logic to ensure share to loan transfers are counted as a single transaction
		   
	),

*/


/* CANT USE THIS YET. This transaction table isn't optimized for this type of querying
	--Initialize Transactions. Extracts all relevant LOAN AND SHARE transaction information from tables
	InitTransactionsCTE AS (
		
		SELECT
			'S' AS 'TransactionType'
			,SavingsTransaction.ParentAccount
			,SavingsTransaction.ParentID
			,Savings.Type
			,SavingsTransaction.ActivityDate
			,SavingsTransaction.LastTranDate
			,SavingsTransaction.EffectiveDate
			,SavingsTransaction.PostDate
			,SavingsTransaction.PostTime
			,SavingsTransaction.Branch
			,SavingsTransaction.UserNumber
			,SavingsTransaction.UserOverride
			,SavingsTransaction.ProcessorUser
			,ABS(SavingsTransaction.BalanceChange) + SavingsTransaction.INTEREST AS 'TransactionAmount' --Check that this works with all interest
			,SavingsTransaction.BalanceChange
			,SavingsTransaction.Interest
			,SavingsTransaction.NewBalance
			,SavingsTransaction.PrevAvailBalance
			,SavingsTransaction.Description
			,SavingsTransaction.SequenceNumber
			,SavingsTransaction.ConfirmationSeq
			,SavingsTransaction.DraftNumber
			,SavingsTransaction.TracerNumber
			,SavingsTransaction.MicrAcctNum
			,SavingsTransaction.ActionCode
			,SavingsTransaction.CommentCode
			,SavingsTransaction.TransferCode
			,SavingsTransaction.AdjustmentCode
			,SavingsTransaction.SourceCode
			,SavingsTransaction.RecurringTran
			,SavingsTransaction.FeeCountBy
		FROM
			SymitarExtracts.dbo.SAVINGSTRANSACTION
			LEFT OUTER JOIN SymitarExtracts.dbo.SAVINGS
				ON Savings.ParentAccount = SAVINGSTRANSACTION.PARENTACCOUNT AND Savings.ID = SAVINGSTRANSACTION.PARENTID
		WHERE 
			COMMENTCODE = 0
			AND ( (@StartDate IS NULL AND Postdate >= CONVERT(DATE,GETDATE()-1)) OR (@StartDate IS NOT NULL AND POSTDATE >= @StartDate))

		UNION

		SELECT
			'L' AS 'TransactionType'
			,LoanTransaction.ParentAccount AS 'ParentAccount'
			,LoanTransaction.ParentID
			,Loan.Type
			,LoanTransaction.ActivityDate
			,LoanTransaction.LastTranDate
			,LoanTransaction.EffectiveDate
			,LoanTransaction.PostDate
			,LoanTransaction.PostTime
			,LoanTransaction.Branch AS 'BranchNumber'
			,LoanTransaction.UserNumber
			,LoanTransaction.UserOverride
			,LoanTransaction.ProcessorUser
			,ABS(LoanTransaction.BalanceChange)+LoanTransaction.INTEREST AS 'TransactionAmount'
			,LoanTransaction.BalanceChange
			,LoanTransaction.Interest
			,LoanTransaction.NewBalance
			,LoanTransaction.PrevAvailBalance
			,LoanTransaction.Description
			,LoanTransaction.SequenceNumber
			,LoanTransaction.ConfirmationSeq
			,LoanTransaction.DraftNumber
			,LoanTransaction.TracerNumber
			,LoanTransaction.MicrAcctNum
			,LoanTransaction.ActionCode
			,LoanTransaction.CommentCode
			,LoanTransaction.TransferCode
			,LoanTransaction.AdjustmentCode
			,LoanTransaction.SourceCode
			,LoanTransaction.RecurringTran
			,LoanTransaction.FeeCountBy
		FROM
			SymitarExtracts.dbo.LoanTransaction
			LEFT OUTER JOIN SymitarExtracts.dbo.Loan
				ON Loan.ParentAccount = LoanTransaction.ParentAccount AND Loan.ID = LoanTransaction.ParentID
		WHERE 
			COMMENTCODE = 0
			AND ( (@StartDate IS NULL AND Postdate >= CONVERT(DATE,GETDATE()-1)) OR (@StartDate IS NOT NULL AND POSTDATE >= @StartDate))
	
	),

	--Used to group transactions by event. Finds when a transfer internal transfers to share or loan and identifies the initiating and ending transfer instance. This is needed to find single event on multiple transactions when TM transfers from account to account
	--TransactionsCTE AS (

	--	SELECT
	--		CASE	WHEN (@Lens = 'Transactions' OR @Lens = 'All') 
	--			THEN	CASE	WHEN UserNumber > 1000 
	--							THEN	CASE	WHEN TransferCode = 1
	--											THEN (ROW_NUMBER() OVER (PARTITION BY transactionAmount, PostDate, PostTime, UserNumber, ConfirmationSEQ, TransferCode ORDER BY sequencenumber)) % 2 --Use Modulo for boolean output and to catch anomalies when TM completes more then 1 transfers in minute
	--											ELSE 1
	--									END
	--							ELSE NULL 
	--					END
	--			ELSE NULL
	--		END AS 'InitialTransaction'
	--		,*
	--	FROM
	--		InitTransactionsCTE

	--),
*/


--:ENDTESTS--






--:BEGINFOOTER--
)
GO
--:ENDFOOTER--

