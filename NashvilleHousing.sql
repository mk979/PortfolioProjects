SELECT * 
FROM housingdata2;

CREATE TABLE housing_data
LIKE housingdata2;

SELECT * 
FROM housing_data;

INSERT housing_data
SELECT *
FROM housingdata2;

-- 1. STANDARDIZE DATE FORMAT

SELECT DISTINCT SaleDate         -- query to identify the formats used in the SaleDate column
FROM housing_data;

SELECT SaleDate, STR_TO_DATE(SaleDate, '%M %d, %Y') AS SaleDateConverted   -- Convert Text Dates to Standard Format
FROM housing_data;

UPDATE housing_data     -- Update the Column (Temporary Storage
SET SaleDate = STR_TO_DATE(SaleDate, '%d/%m/%Y')
WHERE SaleDate REGEXP '^[0-9]{2}/[0-9]{2}/[0-9]{4}$';

ALTER TABLE housing_data     -- Alter the Column to DATE
MODIFY SaleDate DATE;

SELECT *      -- Identifying problematic rows that failed to convert the date format just to be sure all where coverted
FROM housing_data
WHERE SaleDate NOT REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$';

ALTER TABLE housing_data ADD SaleDateConverted DATE;     -- Testing on a New Column to check the conversion 
UPDATE housing_data
SET SaleDateConverted = STR_TO_DATE(SaleDate, '%M %d, %Y')
WHERE SaleDate REGEXP '^[A-Za-z]+ [0-9]{1,2}, [0-9]{4}$';

ALTER TABLE housing_data DROP COLUMN ConvertedDate;     -- drop the old column and rename the new one



-- 2. POPULATE PROPERTYADDRESS WHERE THERE ARE EITHER NULL VALUES OR  EMPTY SPACES
--      use the COALESCE function instead of ISNULL. The COALESCE function allows you to evaluate multiple parameters and returns the first non-NULL value

SELECT *
FROM housing_data 
-- WHERE PropertyAddress = '   ' OR TRIM(PropertyAddress) = ''
ORDER BY ParcelID;

-- explicitly check for empty or whitespace-only strings and provide a fallback value.
SELECT a.ParcelID, a.PropertyAddress, b.ParcelID, b.PropertyAddress,
    CASE 
        WHEN TRIM(a.PropertyAddress) = '' OR a.PropertyAddress = '   ' THEN b.PropertyAddress
        ELSE a.PropertyAddress
    END AS FinalPropertyAddress
FROM housing_data a
JOIN housing_data b
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
WHERE a.PropertyAddress = '   ' OR TRIM(a.PropertyAddress) = '';


UPDATE housing_data a
JOIN housing_data b
    ON a.ParcelID = b.ParcelID
    AND a.UniqueID <> b.UniqueID
SET a.PropertyAddress = b.PropertyAddress
WHERE TRIM(a.PropertyAddress) = '';



-- 3.BREAKING OUT ADDRESS INTO INDIVIDUAL COLUMNS (Address, City, State)
-- a) PropertyAddress

SELECT PropertyAddress
FROM housing_data; 
-- WHERE PropertyAddress = '   ' OR TRIM(PropertyAddress) = ''
-- ORDER BY ParcelID;

SELECT 
SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) -1 ) AS Address,
SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress) + 1 , LENGTH(PropertyAddress)) AS Address 
FROM housing_data;

ALTER TABLE housing_data
ADD PropertySplitAddress VARCHAR(255);

UPDATE housing_data
SET PropertySplitAddress = SUBSTRING(PropertyAddress, 1, LOCATE(',', PropertyAddress) -1 );

ALTER TABLE housing_data
ADD PropertySplitCity VARCHAR(255);

UPDATE housing_data
SET PropertySplitCity = SUBSTRING(PropertyAddress, LOCATE(',', PropertyAddress) + 1 , LENGTH(PropertyAddress));

SELECT *
FROM housing_data; 


-- b) OwnerAddress

SELECT OwnerAddress
FROM housing_data; 

SELECT 
SUBSTRING_INDEX(OwnerAddress, ',', 1) AS Part1,  -- First segment
SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1) AS Part2,  -- Second segment
SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 3), ',', -1) AS Part3  -- Third segment
FROM housing_data;

ALTER TABLE housing_data
ADD OwnerSplitAddress VARCHAR(255);

UPDATE housing_data
SET OwnerSplitAddress = SUBSTRING_INDEX(OwnerAddress, ',', 1);

ALTER TABLE housing_data
ADD OwnerSplitCity VARCHAR(255);

UPDATE housing_data
SET OwnerSplitCity = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 2), ',', -1);

ALTER TABLE housing_data
ADD OwnerSplitState VARCHAR(255);

UPDATE housing_data
SET OwnerSplitState = SUBSTRING_INDEX(SUBSTRING_INDEX(OwnerAddress, ',', 3), ',', -1);

SELECT *
FROM housing_data; 



-- 4. CHANGE Y AND N TO YES AND NO IN "SoldAsVacant" FIELD

SELECT DISTINCT(SoldAsVacant), COUNT(SoldAsVacant)
FROM housing_data
GROUP BY SoldAsVacant
ORDER BY 2; 

SELECT SoldAsVacant,
CASE WHEN SoldAsVacant = 'Y' THEN 'YES'
	 WHEN SoldAsVacant = 'N' THEN 'NO'
	 ELSE SoldAsVacant
     END
FROM housing_data;

UPDATE housing_data
SET SoldAsVacant = CASE WHEN SoldAsVacant = 'Y' THEN 'YES'
	 WHEN SoldAsVacant = 'N' THEN 'NO'
	 ELSE SoldAsVacant
     END;
     
     
-- 5. REMOVE DUPLICATES

SELECT * FROM housing_data
WHERE UniqueID NOT IN (    -- NOT IN Deletes all rows where the UniqueID is not the minimum for its group
    SELECT MIN(UniqueID)  -- This ensures that only the first occurrence of each group of duplicates (based on ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference) is retained.
    FROM housing_data
    GROUP BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference  -- Groups the rows by the specified columns to identify duplicates
);

WITH RowNumCTE AS (
    SELECT UniqueID
    FROM (
        SELECT UniqueID, ROW_NUMBER() OVER (
            PARTITION BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference
            ORDER BY UniqueID
        ) AS row_num
        FROM housing_data
    ) subquery
    WHERE row_num = 1
)
DELETE FROM housing_data
WHERE UniqueID NOT IN (SELECT UniqueID FROM RowNumCTE);  -- ensures only the rows with row_num = 1 (first occurrence) are retained.
-- OR A Temporary Table could also have worked as below 
CREATE TEMPORARY TABLE TempDuplicates AS
SELECT MIN(UniqueID) AS KeepUniqueID
FROM housing_data
GROUP BY ParcelID, PropertyAddress, SalePrice, SaleDate, LegalReference;

DELETE FROM housing_data
WHERE UniqueID NOT IN (SELECT KeepUniqueID FROM TempDuplicates);



-- 6. DELETE Unused COLUMNS

SELECT *
FROM housing_data;

ALTER TABLE housing_data
DROP COLUMN OwnerAddress,
DROP COLUMN TaxDistrict,
DROP COLUMN PropertyAddress;

DESCRIBE housing_data;

ALTER TABLE housing_data
DROP COLUMN SaleDate;