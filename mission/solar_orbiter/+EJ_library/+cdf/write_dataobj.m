function write_dataobj(filePath, ...
    dataobj_GlobalAttributes, dataobj_data, dataobj_VariableAttributes, dataobj_Variables, varargin)
%
% Function which writes a CDF file.
%
% Attempt at a function which can easily write a CDF using variables on the same data format as returned by dataobj
% (irfu-matlab). Useful for reading a CDF file, modifying the contents somewhat, and then writing the modified contents
% to a CDF file. Originally based on write_cdf.m/write_cdf_spdfcdfread.m.
%
%
% Author: Erik P G Johansson, IRF, Uppsala, Sweden
% First created 2016-07-12 (as write_cdf.m/write_cdf_spdfcdfread.m), 2016-10-20 (as write_cdf_dataobj.m)
%
%
%
% ARGUMENTS
% =========
% filePath                    : Path to file to create.
% dataobj_GlobalAttributes    : The corresponding field of an instantiated dataobj. Struct where
%                               .<global attribute name>{i} = global attribute value as string (must be strings?).
%                               NOTE: Unclear if cell array must be 1D.
% dataobj_data                : The corresponding field of an instantiated dataobj. Struct where
%                               .<zVariable name>.data = Array (numeric or char) corresponding to the content of the zVar.
%                                   Indices for numeric arrays: (iRecord, i1, i2, ...)
%                                   Indices for char    arrays: Same as in dataobj.data.<zVarName>.data, i.e. inconsistent.
%                               .<zVariable name>.dim  = NOT USED. dataobj: Size of record. Row vector, at least length 2.
%                               NOTE: May have other fields than ".data" which are then ignored.
% dataobj_VariableAttributes  : The corresponding field of an instantiated dataobj. Struct where
%                               .<zVariable attribute name>{iZVar, 1} = zVariable name
%                               .<zVariable attribute name>{iZVar, 2} = zVariable attribute value
% dataobj_Variables           : The corresponding field of an instantiated dataobj. Nx12 cell array where
%                               {iZVar,  1} = zVariable name
%                               {iZVar,  2} = Size of record. Row vector, at least length 2.
%                               {iZVar,  3} = NOT USED. dataobj: Uknown meaning. Scalar number.
%                               {iZVar,  4} = String representing data type (tt2000, single, char etc)
%                               {iZVar,  5} = NOT USED. dataobj: "Record variance", string representing on which
%                                             dimensions the zVariable changes. T=True, F=False.
%                               {iZVar,  6} = NOT USED. dataobj: Uknown meaning. String = 'Full' (always?)
%                               {iZVar,  7} = NOT USED. dataobj: Uknown meaning. String = 'None' (always?)
%                               {iZVar,  8} = NOT USED. dataobj: Uknown meaning. Scalar number
%                               {iZVar,  9} = Pad value
%                               {iZVar, 10} = NOT USED. dataobj: Uknown meaning. Scalar number or empty.
%                               {iZVar, 11} = NOT USED. dataobj: Uknown meaning. Scalar number or empty.
%                               {iZVar, 12} = NOT USED. dataobj: Uknown meaning. Scalar number or empty.
% varargin                    : Settings passed to EJ_library.utils.interpret_settings_args. See implementation.
%
%
%
% LIMITATIONS
% ===========
% NOTE/PROBLEM: spdfcdfread and spdfcdfinfo may crash MATLAB(!) when reading files written with spdfcdfwrite (which this
% function uses). It appears that this happens when spdfcdfwrite receives various forms of "incomplete" input data.
% spdfcdfwrite appears to often not give any warning/error message when receiving such data and writes a file anyway
% with neither error nor warning. Before passing data to spdfcdfwrite, this function tries to give errors for, or
% correct such data, but can only do so as far as the problem is understood by the author. Submitting empty data for a
% CDF variable is one such case. Therefore, despite best efforts, this function might still produce nonsensical files
% instead of producing any warning or error message.
%
% NOTE PROBLEM(?): Can not select CDF encoding (Network/XDR, IBMPC etc) when writing files. The NASA SPDF MATLAB CDF
% Software distribution does not have this option (this has been confirmed with their email support 2016-07-14).
%
% BUG: Variable attributes SCALEMIN, SCALEMAX for Epoch are stored as CDF_INT8 (not CDF_TT2000) in the final CDF file.
% The information stored seems correct though. Therefore, the same variable attributes are also represented as integers
% when reading the CDF file with dataobj.
%
% BUG/NOTE: spdfcdfwrite has been observed to set the wrong pad value when writing 0 records.
%
% NOTE: spdfcdfwrite always writes char as UCHAR (not CHAR) in the CDF.
%
% NOTE: The exact stated zVar dimensionality per record may be slightly wrong with regard to size=1 dimension:
% --The exact zvar size may be wrong. CDF file zVars of size 1 (scalar) per record may, in the CDF file, have
% specified record size "1:[1]" for 0--1 records, and "0:[]" for >=2 records as displayed by cdfdump.
% --zVar dimensionality per record may have all its trailing ones removed (except for the case above).
%
% NOTE: dataobj may permute zVar dimensions for unknown reason (irfu-matlab commit 1a9a7c32, branch SOdevel).
% Ex: BIAS RCT zVar TRANSFER_FUNCTION_COEFFS (3 dimensions per record).
%
%
% IMPLEMENTATION NOTES
% ====================
% -- To keep the function as generic as possible, it does not contain any log messages.
% -- The function does not accept a whole dataobj object since:
% (1) instances of dataobj are likely NOT meant to be modified after creation. Empirically, it is possible to modify
% them in practice though. Therefore the function only accepts the parts of a dataobj that it really needs, which still
% means it accepts a lot of redundant information in the arguments.
% (2) One might want to use the function for writing a CDF file without basing it on a dataobj (i.e. without basing it
% on an existing CDF file).
%
%
% IMPLEMENTATION NOTE ON "spdfcdfwrite" AND CHAR ZVARIABLES
% =========================================================
% The behaviour of spdfcdfwrite when passing char arrays or cell arrays of strings for zVariables is very mysterious and
% hard to understand. Below is the empirical behaviour from passing such arrays to spdfcdfwrite (RecordBound option
% disabled option, Singleton option enabled).
% --
% i = index within record. N,M,K>1
% Left  column = Size of CHAR ARRAY passed to scpdfcdfwrite.
% Right column = Result read from cdfdump (not dataobj).
% 0x0   : Error
% Mx1   : 1 record, M=i,     1 char/string!
% 1xN   : 1 record, N=strLen
% 1x1xK : 1 record, 1 char/string, all but first char lost!
% MxN   : 1 record, M=i, N=strLen
% MxNxK : 1 record, M=i, N=strLen, all but K index value=1 lost!
% NOTE: For the above, only 1 record is produced in all cases.
% NOTE: For the above, using RecordBound ONLY leads to more data being lost/ignored for some cases.
% --
% Left column  = Size of CELL ARRAY (of strings) passed to spdfcdfwrite.
% Right column = Result read from cdfdump (not dataobj).
% 0x0 : zVar is not written to file (still no error)!
% 1x1 : 1 record, 1 string/record
% 1x2 : 1 record, 2 strings/record
% 2x1 : 2 records, 1 string/record
% 3x2 : 3 records, 2 strings/record, BUT the strings are placed ILLOGICALLY/IN THE WRONG POSITIONS!
% 2x3 : 2 records, 3 strings/record. Strings are placed logically.
% NOTE: No alternative gives 1 record, with multiple strings.
% NOTE: For the above, using RecordBound makes no difference.
% --
% NOTE: dataobj always returns a char array but the meaning of indices seems to vary.



%=======================================================================================================================
% PROPOSAL: Implement using NASA SPDFs Java code instead?!! Should be possible to easily call Java code from inside MATLAB.
%   PRO?: Java interface might be more easy to work with and have fewer quirks & limitations.
%
% PROPOSAL: Option for filling empty variable with pad values. 1 record?
%    CON: Can not know the (non-record) dimensions of such a CDF variable.
%    CON: Using exactly one record automatically leads to the CDF labelling the CDF variable as record-invariant!
%    CON: May not fit any zvar attribute DEPEND_x (zvar must have same length as other zvar).
%
% PROPOSAL: Reorganize into write_dataobj calling more genering function write_CDF which assumes more generic data
% structures.
%   PROPOSAL: Useful for combining with future generic function read_CDF which could replace dataobj.
%       NOTE/CON: spdfcdfread returns some data structures similar to what dataobj contains so the gain might be small.
%
% PROPOSAL: Create analogous read_CDF+write_CDF (which use the same data structures). Combine with proper test code.
%   NOTE: This current code is based on writing a modified dataobj to disk, which is not necessarily desirable for a
%         general-purpose function write_CDF function.
%
%
% PROPOSAL: Some form of validation of input.
%    PROPOSAL: Assertions for redundant data (within dataobj data/attributes).
%       PROPOSAL: Check that both stated zvar sizes (within record) are consistent.
%       PROPOSAL: Check that stated nbr of records fits data.
%
% PROPOSAL: Shorten for-loop over zvars, by outsourcing tasks to functions.
%
% PROPOSAL: Write zVars using cell arrays of records (matrices) (spdfcdfwrite permits it; see "RecordBound").
%
% PROPOSAL: Flag for different interpretations of indices in char arrays (dataobj or logical).
% PROPOSAL: Flag for assertion on preventing NaN.
%
% PROPOSAL: Check for illegal characters (or at least, characters which can not be handled) in global attributes:
%           åäöÅÄÖ, quotes(?).
%   NOTE: According to old notes, åäöÅÄÖ will be invisible global attributes, but the corresponding number of characters
%   will be cut out from the end.
%
% ~BUG: Zero-record numeric & char zVars are converted to [] (numeric, always 0x0) by dataobj. This code does not take
% this into account by internally converting the zVar variable back to the right class and size.


% zVariable attributes that should reasonably have the same data type as the zVariable itself.
ZVAR_ATTRIBUTES_OF_ZVAR_DATA_TYPE = {'VALIDMIN', 'VALIDMAX', 'SCALEMIN', 'SCALEMAX', 'FILLVAL'};

% NOTE: 'disableSpdfcdfwrite' : Useful for debugging test runs.
DEFAULT_SETTINGS = struct(...
    'strictNumericZvSizePerRecord',      1, ...   % Whether zVariable value size per record must fit the submitted metadata (dataobj_Variables{i, 2}).
    'strictEmptyNumericZvSizePerRecord', 1, ...   % Default 1/true since dataobj is not strict about size of  empty zVars.
    'strictEmptyZvClass',                1, ...   % Default 1/true since dataobj is not strict about class or empty zVars.
    'calculateMd5Checksum',              1, ...
    'disableSpdfcdfwrite',               0);
Settings = EJ_library.utils.interpret_settings_args(DEFAULT_SETTINGS, varargin);
EJ_library.assert.struct(Settings, fieldnames(DEFAULT_SETTINGS), {})



zVarNameAllList1 = dataobj_Variables(:, 1);   % Previously called for only non-char data. Why?
zVarNameAllList2 = fieldnames(dataobj_data);



% ASSERTION: zVariable names are all unique.
EJ_library.assert.castring_set(zVarNameAllList1)
% if length(unique(zVarNameAllList1)) ~= length(zVarNameAllList1)
%     % IMPLEMENTATION NOTE: Could be useful for test code which may generate zVar names automatically.
%     error('write_dataobj:Assertion', 'Not all zVariable names are unique.')
% end
% ASSERTION: Arguments contain two consistent lists of zVariables.
EJ_library.assert.castring_sets_equal(zVarNameAllList1, zVarNameAllList2)
% if ~isempty(setxor(zVarNameAllList1, zVarNameAllList2))
%     error('write_dataobj:Assertion', 'Arguments contain two inconsistent lists of available zVariable names.')
% end

zVarNameAllList = zVarNameAllList1;
clear zVarNameAllList1 zVarNameAllList2



%============================================================
% Construct variables that spdfcdfwrite accepts as arguments
%============================================================
zVarNameRcList          = {};   % RC = spdfcdfwrite option "RecordBound".
zVarNameAndValueList    = {};   % List consisting of alternating zVar names and corresponding zVar values (needed for spdfcdfwrite).
zVarNameAndDataTypeList = {};   % List consisting of alternating zVar names and corresponding data types  (needed for spdfcdfwrite).
zVarNameAndPadValueList = {};   % List consisting of alternating zVar names and corresponding pad values  (needed for spdfcdfwrite).

for i = 1:length(dataobj_Variables(:,1))
    
    %===============================================================================================================
    % Extract zVariable data from arguments
    % -------------------------------------
    % IMPLEMENTATION NOTE: Not using (1) data(i).VariableName or (2) info.Variables(:,1) to obtain the variable name
    % since experience shows that components of (1) can be empty (contain empty struct fields) and (2) may not cover
    % all variables when obtained via spdfcdfread!!
    %===============================================================================================================
    zVarName               = dataobj_Variables{i, 1};
    specifiedSizePerRecord = dataobj_Variables{i, 2};
    % "CdfDataType" refers to that the value should be interpreted as a CDF standard string for
    % representing data type (not a MATLAB class/type): uint32, tt2000 etc.
    specifiedCdfDataType   = dataobj_Variables{i, 4};
    padValue               = dataobj_Variables{i, 9};   % This value can NOT be found in dataobj_data. Has to be read from dataobj_Variables.
    
    zVarValue            = dataobj_data.(zVarName).data;
    specifiedMatlabClass = EJ_library.cdf.convert_CDF_type_to_MATLAB_class(specifiedCdfDataType, 'Permit MATLAB classes');
    
    
    
    % ASSERTION: No zero-size dimensions (in size per record)
    %
    % IMPLEMENTATION NOTE: Code can not handle zero size dimensions (in size per record).
    % In practice: #records > 0 with zero-size records ==> zero records
    % Not certain that the CDF files format is meant to handle this either.
    if prod(specifiedSizePerRecord) == 0
        error('write_dataobj:Assertion', ...
            'Specified size per record contains zero-size dimension(s). This function can not handle this case.')
    end
    
    %zVarData = handle_zero_records(zVarData, padValue, dataobjStatedMatlabClass, turnZeroRecordsIntoOneRecord);



    %===================================================================================================================
    % ASSERTION:
    %   Check that the supplied zVariable data variable has a MATLAB class (type) which matches the specified CDF type.
    % -----------------------------------------------------------------------------------------------------------------
    % IMPLEMENTATION NOTE:
    % (1) Empty data (empty arrays) from spdfcdfread are known to have the wrong data type (char).
    % Therefore, do this check after having dealt with empty data.
    % (2) Must do this after converting time strings (char) data to uint64/tt2000.
    %===================================================================================================================
    zVarDataMatlabClass = class(zVarValue);    
    
    %if ~(~Settings.strictEmptyZvClass && isempty(zVarValue)) && ~strcmp( specifiedMatlabClass, zVarDataMatlabClass )
    if ~strcmp( specifiedMatlabClass, zVarDataMatlabClass ) && (Settings.strictEmptyZvClass || ~isempty(zVarValue))
        error('write_dataobj:Assertion', ...
            'The MATLAB class ("%s") of the variable containing zVariable ("%s") data does not match specified CDF data type "%s".', ...
            zVarDataMatlabClass, zVarName, specifiedCdfDataType)
    end
    
    

    [zVarValue, isRecordBound] = prepare_zVarData(zVarValue, specifiedSizePerRecord, Settings, zVarName);
    if isRecordBound
        zVarNameRcList{end+1} = zVarName;
    end



    %===========================================================================================================
    % Convert specific VariableAttributes values.
    % Case 1: tt2000 values as UTC strings : Convert to tt2000.
    % Case 2: All other                    : Convert to the zVariable data type.
    % --------------------------------------------------------------------------
    % IMPLEMENTATION NOTE: spdfcdfread (not spdfcdfwrite) can crash if not doing this!!!
    %                      The tt2000 CDF variables are likely the problem(?).
    %
    % BUG: Does not seem to work on SCALEMIN/-MAX specifically despite identical treatment, for unknown reason.
    %===========================================================================================================
    for iVarAttrOfVarType = 1:length(ZVAR_ATTRIBUTES_OF_ZVAR_DATA_TYPE)
        varAttrName = ZVAR_ATTRIBUTES_OF_ZVAR_DATA_TYPE{iVarAttrOfVarType};
        if ~isfield(dataobj_VariableAttributes, varAttrName)
            continue
        end
        
        % IMPLEMENTATION NOTE: Can NOT assume that every CDF variable is represented among the cell arrays in
        %                      dataobj_VariableAttributes.(...).
        % Example: EM2_CAL_BIAS_SWEEP_LFR_CONF1_1M_2016-04-15_Run1__e1d0a9a__CNES/ROC-SGSE_L2R_RPW-LFR-SURV-CWF_e1d0a9a_CNE_V01.cdf
        doVarAttrField = dataobj_VariableAttributes.(varAttrName);   % DO = dataobj. This variable attribute (e.g. VALIDMIN) for alla zVariables (where present). Nx2 array.
        iAttrZVar      = find(strcmp(doVarAttrField(:,1), zVarName));
        if isempty(iAttrZVar)
            % CASE: The current zVariable does not have this attribute (varAttrName).
            continue
        elseif length(iAttrZVar) > 1
            error('write_dataobj:Assertion:OperationNotImplemented', ...
                'Can not handle multiple variable name matches in dataobj_VariableAttributes.%s.', varAttrName)
        end
        varAttrValue = doVarAttrField{iAttrZVar, 2};
        if strcmp(specifiedCdfDataType, 'tt2000') && ischar(varAttrValue)
            varAttrValue = spdfparsett2000(varAttrValue);   % Convert char-->tt2000.
            
        %elseif ~strcmp(specifiedCdfDataType, class(varAttrValue))
        elseif ~strcmp(specifiedMatlabClass, class(varAttrValue))
            error('write_dataobj:Assertion', ...
                ['Found VariableAttribute %s for CDF variable "%s" whose data type did not match the declared one.', ...
                ' specifiedCdfDataType="%s", specifiedMatlabClass="%s", class(varAttrValue)="%s"'], ...
                varAttrName, zVarName, specifiedCdfDataType, specifiedMatlabClass, class(varAttrValue))
        end
        
        % Modify dataobj_VariableAttributes correspondingly.
        doVarAttrField{iAttrZVar, 2} = varAttrValue;
        dataobj_VariableAttributes.(varAttrName) = doVarAttrField;
    end
    
    zVarNameAndValueList   (end+[1,2]) = {zVarName, zVarValue           };
    zVarNameAndDataTypeList(end+[1,2]) = {zVarName, specifiedCdfDataType};
    zVarNameAndPadValueList(end+[1,2]) = {zVarName, padValue            };
end    % for

% dataobj_VariableAttributes = rmfield(dataobj_VariableAttributes, {'VALIDMIN', 'VALIDMAX', 'SCALEMIN', 'SCALEMAX', 'FILLVAL'});



%===================================================================================================
% RELEVANT spdfcdfwrite OPTIONS:
% (Relevant excerpts from spdfcdfwrite.m COPIED here for convenience.)
% --------------------------------------------------------------------
%   SPDFCDFWRITE(FILE, VARIABLELIST, ...) writes out a CDF file whose name
%   is specified by FILE.  VARIABLELIST is a cell array of ordered
%   pairs, which are comprised of a CDF variable name (a string) and
%   the corresponding CDF variable value.  To write out multiple records
%   for a variable, there are two ways of doing it. One way is putting the
%   variable values in a cell array, where each element in the cell array
%   represents a record. Another way, the better one, is to place the
%   values in an array (single or multi-dimensional) with the option
%   'RecordBound' being specified.
%
%   SPDFCDFWRITE(..., 'RecordBound', RECBNDVARS) specifies data values in arrays
%   (1-D or multi-dimensional) are to be written into "records" for the given
%   variable. RECBNDVARS is a cell array of variable names. The M-by-N array
%   data will create M rows (records), while each row having N elements. For
%   examples, 5-by-1 array will create five (5) scalar records and 1-by-5 array
%   will write out just one (1) record with 5 elements. For 3-D array of
%   M-by-N-by-R, R records will be written, and each record with M-by-N
%   elements. Without this option, array of M-by-N will be written into a single
%   record of 2-dimensions. See sample codes for its usage.
%
%   SPDFCDFWRITE(..., 'GlobalAttributes', GATTRIB, ...) writes the structure
%   GATTRIB as global meta-data for the CDF.  Each field of the
%   struct is the name of a global attribute.  The value of each
%   field contains the value of the attribute.  To write out
%   multiple values for an attribute, the field value should be a
%   cell array.
%
%   If there is a master CDF that has all the meta-data that the new CDF needs,
%   then SPDFCDFINFO module can be used to retrieve the infomation. The
%   'GlobalAttributes' field from the returned structure can be
%   passed in for the GATTRIB.
%
%   In order to specify a global attribute name that is illegal in
%   MATLAB, create a field called "CDFAttributeRename" in the
%   attribute struct.  The "CDFAttribute Rename" field musdataobjStatedMatlabClasst have a value
%   which is a cell array of ordered pairs.  The ordered pair consists
%   of the name of the original attribute, as listed in the
%   GlobalAttributes struct and the corresponding name of the attribute
%   to be written to the CDF.
%
%   SPDFCDFWRITE(..., 'VariableAttributes', VATTRIB, ...) writes the
%   structure VATTRIB as variable meta-data for the CDF.  Each
%   field of the struct is the name of a variable attribute.  The
%   value of each field should be an Mx2 cell array where M is the
%   number of variables with attributes.  The first element in the
%   cell array should be the name of the variable and the second
%   element should be the value of the attribute for that variable.
%
%   If there is a master CDF that has all the meta-data that the new CDF needs,
%   then SPDFCDFINFO module can be used to retrieve the infomation. The
%   'VariableAttributes' field from the returned structure can
%   be passed in for the VATTRIB.
%
%   In order to specify a variable attribute name that is illegal in
%   MATLAB, create a field called "CDFAttributeRename" in the
%   attribute struct.  The "CDFAttribute Rename" field must have a value
%   which is a cell array of ordered pairs.  The ordered pair consists
%   of the name of the original attribute, as listed in the
%   VariableAttributes struct and the corresponding name of the attribute
%   to be written to the CDF.   If you are specifying a variable attribute
%   of a CDF variable that you are re-naming, the name of the variable in
%   the VariableAttributes struct must be the same as the re-named variable.
%
%   SPDFCDFWRITE(..., 'Vardatatypes', VARDATATYPE) specifies the variable's
%   data types. By default, this module uses each variable's passed data to
%   determine its corresponding CDF data type. While it is fine for the most
%   cases, this will not work for the CDF epoch types, i.e., CDF_EPOCH (a double),
%   CDF_EPOCH16 (an array of 2 doubles) and CDF_TIME_TT2000 (an int64). This
%   option can be used to address such issue. VARDATATYPE is a cell array of
%   variable names and their respective data types (in string).
%
%   The following table shows the valid type strings, either in CDF defined
%   forms, or alternatively in the forms presented at column 4 in the Variables
%   field of the structure returned from a SPDFCDFINFO module call to an
%   existing CDF or master CDF.
%       type             CDF Types
%       -----            ---------
%       int8             CDF_INT1 or CDF_BYTE
%       int16            CDF_INT2
%       int32            CDF_INT4
%       int64            CDF_INT8
%       uint8            CDF_UINT1
%       uint16           CDF_UINT2
%       uint32           CDF_UINT4
%       single           CDF_FLOAT or CDF_REAL4
%       double           CDF_DOUBLE or CDF_REAL8
%       epoch            CDF_EPOCH
%       epoch16          CDF_EPOCH16
%       tt2000           CDF_TIME_TT2000
%       char             CDF_CHAR or CDF_UCHAR
%
%   Note: Make sure variable's data match to the defined type.
%
%   SPDFCDFWRITE(..., 'PadValues', PADVALS) writes out pad values for given
%   variable names.  PADVALS is a cell array of ordered pairs, which
%   are comprised of a variable name (a string) and a corresponding
%   pad value.  Pad values are the default value associated with the
%   variable when an out-of-bounds record is accessed.  Variable names
%   that appear in PADVALS must appear in VARIABLELIST.
%
%   SPDFCDFWRITE(..., 'Singleton', VARS, ...) indicates whether to keep the
%   singleton dimension(s) passed in from the multi-dimensional data. VARS is
%   a cell array of variable names, indicating each variable's singleton
%   dimension(s) is to be kept.
%   For example, variable with data dimensions like 10x1x100 will be written
%   as 2-dimensions (10x1) for 100 records if the record bound is specified.
%   For a row (1-by-M) or column (M-by-1) vector, the variable data will be
%   written as 2-dimension as is, unless the recordbound is specified.
%   The default setting is to have all singleton dimension(s) removed.
%   The above 10x1x100 variable will be written as 1-dimension
%   (with 10 elements).
%===================================================================================================
if Settings.calculateMd5Checksum ; checksumFlagArg = 'MD5';
else                             ; checksumFlagArg = 'None';
end

if ~Settings.disableSpdfcdfwrite
    spdfcdfwrite(...
        filePath, zVarNameAndValueList(:), ...
        'RecordBound',        zVarNameRcList, ...
        'GlobalAttributes',   dataobj_GlobalAttributes, ...
        'VariableAttributes', dataobj_VariableAttributes, ...
        'Vardatatypes',       zVarNameAndDataTypeList, ...
        'PadValues',          zVarNameAndPadValueList, ...
        'Singleton',          zVarNameAllList, ...
        'Checksum',           checksumFlagArg)
end

end



% Convert a char array that dataobj returns into a char array that prepare_char_zVarData interprets the same way.
%
% ARGUMENTS
% =========
% charArray : Char array with indices (iRecord,iCharWithinString,)
function charArray = convert_dataobj_charZVarValue_2_consistent_charZVarValue(charArray, nWrd1)
    % ASSERTION
    assert(isscalar(nWrd1), 'write_dataobj:Assertion', 'Argument nWrd1 is not a scalar.')

    if nWrd1 == 1
        charArray = permute(charArray, [2,1,3]);
    else
        charArray = permute(charArray, [2,3,1]);
    end
end



% Function for converting a char array representing a char zVariable using a consistent and logical indexing scheme,
% into the VERY HARD-TO-UNDERSTAND scheme that spdfcdfwrite requires to produce the desired zVariable.
%
% NOTE: If one wants another order of indices for charArray, then one should use permute() rather than change the
% algorithm.
%
%
% ARGUMENTS
% =========
% charArray     : Array of chars with indices (iCharWithinString, iRecord, iWrd). WRD = Within-Record Dimension
%                 Must not have more dimensions than 3.
%                 Must not have 0 elements.
%                 Must not have both multiple records AND multiple strings per record(!).
%
%
% RETURN VALUES
% =============
% zVarData      : The variable that should be passed to spdfcdfwrite. Can be (1) char array, or (2) cell array of strings.
% isRecordBound : True/false. Whether the zVariable should be passed to spdfcdfwrite with option "RecordBound" enabled.
function [zVarValue, isRecordBound] = prepare_char_zVarData(charArray)
    % ASSERTIONS. Important to check that the code can actually handle the case.
    assert(ischar(charArray), ...
        'write_dataobj:Assertion', 'Argument charArray is not a char array.')
    assert(ndims(charArray) <= 3, ...
        'write_dataobj:Assertion:OperationNotImplemented', ...
        'Argument charArray has more than 3 dimension (2 per record). Can not produce value for such zVariable.')
    assert(~isempty(charArray), ...
        'write_dataobj:Assertion:OperationNotImplemented', ...
        'Argument charArray constains zero strings. Can not produce value for empty zVariable.')
    
    nRecords = size(charArray, 2);   % CASE: >=1, because of assertion.
    nWrd1    = size(charArray, 3);   % CASE: >=1, because of assertion. WRD1 = Within-Record Dimension 1.    
    
    if nRecords == 1
        if nWrd1 == 1
            zVarValue = permute(charArray, [2, 1, 3]);
        else
            zVarValue = permute(charArray, [3, 1, 2]);
        end
    else
        if nWrd1 == 1
            zVarValue = cell(nRecords, nWrd1);
            for iRecord = 1:nRecords
                for iWrd1 = 1:nWrd1
                    zVarValue{iRecord, nWrd1} = permute(charArray(:, iRecord, iWrd1), [2,1,3]);
                end
            end
        else
            error('write_dataobj:Assertion:OperationNotImplemented', 'Argument charArray represents multiple records containing multiple strings per record. Can not produce zVariable value for this case.');
        end
    end    
    
    isRecordBound = 0;    % Always!
end



% Modify zVarData so that it can be passed to spdfcdfwrite and be interpreted correctly.
%
% ARGUMENTS
% =========
% zVarData :               If numeric array, indices (iRecord, i1, i2, ...)
%                          If char array, indices are the same as in dataobj.data.<zVarName>.data, i.e. inconsistent.
% specifiedSizePerRecord : Size per record used for assertion.
%                          For numeric: zValue size minus the first value, "size(zVarValue)(2:end)".
function [zVarValue, isRecordBound] = prepare_zVarData(zVarValue, specifiedSizePerRecord, Settings, zVarName)

if ischar(zVarValue)
    %===========================================================================================================
    % CASE: char zVar: Convert 3-D char matrices to column cell arrays of 2-D char matrices.
    % ----------------------------------------------------------------------------------------------
    % IMPLEMENTATION NOTE: It is not possible to permute indices for string as one can for non-char for ndim==3.
    %===========================================================================================================

    zVarValue = convert_dataobj_charZVarValue_2_consistent_charZVarValue(zVarValue, specifiedSizePerRecord(1));
    
    %=======================================
    % ASSERTION: Check zVar size per record
    %=======================================
    % NOTE: This check can not be perfect since zVarValue with multiple strings can be interpreted correctly for two
    % different values of specifiedSizePerRecord: 1 (multiple strings in one record) and non-1 (multiple records, with
    % one string per record).
    temp          = size(zVarValue);
    sizePerRecord = temp(3:end);   % NOTE: Throw away indices iRecord and iCharWithinString.
    if ~isequal(...
            normalize_size_vec(specifiedSizePerRecord), ...
            normalize_size_vec(sizePerRecord))
        error('write_dataobj:Assertion', ...
            'The zVariable data size (dataobj_data.(''%s'').data) does not fit the stated size per record (dataobj_Variables).', ...
            zVarName)
    end
    
    [zVarValue, isRecordBound] = prepare_char_zVarData(zVarValue);



elseif isnumeric(zVarValue)
    
    nRecords = size(zVarValue, 1);
    if Settings.strictNumericZvSizePerRecord || (Settings.strictEmptyNumericZvSizePerRecord && (nRecords == 0))
        % NOTE: dataobj zVar data is always (empirically) [] (i.e. numeric 0x0) when nRecords=0,
        %   i.e. also for char-valued zVars, and also for non-empty size per record. Therefore often needs to be
        %   tolerant of this. Note that the code can not (?) reconstruct an original char zVar from dataobj for
        %   nRecords=0 since it does not have the length of the strings.
        
        %=======================================
        % ASSERTION: Check zVar size per record
        %=======================================
        temp          = size(zVarValue);
        sizePerRecord = temp(2:end);
        if ~isequal(...
                normalize_size_vec(specifiedSizePerRecord), ...
                normalize_size_vec(sizePerRecord))
            error('write_dataobj:Assertion', ...
                ['The zVariable (''%s'') data size according to data variable itself is not', ...
                ' consistent with the stated size per record in other argument.\n', ...
                '    Size per record according to data variable produced by processing: [', sprintf('%i ', sizePerRecord),          ']\n', ...
                '    Size per record separately specified:                              [', sprintf('%i ', specifiedSizePerRecord), ']'], ...
                zVarName)
        end
    end



    %===========================================================================================================
    % Special behaviour for numeric matrices with >=2D per record
    % -----------------------------------------------------------
    % For 3D matrices, spdfcdfwrite interprets the last index (not the first index!) as the record number.
    % Must therefore permute the indices so that write_cdf2 is consistent for all numbers of dimensions.
    %     write_dataobj data arguments : index 1 = record.
    %     matrix passed on to spdfcdfwrite : index 3 = record.
    % NOTE: spdfcdfread (at least with argument "'Structure', 1, 'KeepEpochAsIs', 1") works like spdfcdfwrite in
    % this regard.
    %
    % Excerpt from the comments in "spdfcdfwrite.m":
    % ----------------------------------------------
    %   """"SPDFCDFWRITE(..., 'RecordBound', RECBNDVARS) specifies data values in arrays
    %   (1-D or multi-dimensional) are to be written into "records" for the given
    %   variable. RECBNDVARS is a cell array of variable names. The M-by-N array
    %   data will create M rows (records), while each row having N elements. For
    %   examples, 5-by-1 array will create five (5) scalar records and 1-by-5 array
    %   will write out just one (1) record with 5 elements. For 3-D array of
    %   M-by-N-by-R, R records will be written, and each record with M-by-N
    %   elements. Without this option, array of M-by-N will be written into a single
    %   record of 2-dimensions. See sample codes for its usage.""""
    %
    %   """"SPDFCDFWRITE(..., 'Singleton', VARS, ...) indicates whether to keep the
    %   singleton dimension(s) passed in from the multi-dimensional data. VARS is
    %   a cell array of variable names, indicating each variable's singleton
    %   dimension(s) is to be kept.
    %   For example, variable with data dimensions like 10x1x100 will be written
    %   as 2-dimensions (10x1) for 100 records if the record bound is specified.
    %   For a row (1-by-M) or column (M-by-1) vector, the variable data will be
    %   written as 2-dimension as is, unless the recordbound is specified.
    %   The default setting is to have all singleton dimension(s) removed.
    %   The above 10x1x100 variable will be written as 1-dimension
    %   (with 10 elements).""""
    %===========================================================================================================
    %if nRecords == 0
    %    zVarValue = zeros(sizePerRecord);
    %else
    if nRecords == 1
        % Shift/permute indices "left" so that index 1 appears last (and hence "disappears" since it is size=1 due to
        % how MATLAB handles indices).
        zVarValue = shiftdim(zVarValue, 1);
        isRecordBound = 0;
    else
        % CASE: First index size>=2.
        if ndims(zVarValue) >= 3
            % Shift/permute indices "left" so that index 1 appears last where it will be interpreted as number of
            % records.
            zVarValue = shiftdim(zVarValue, 1);
        end
        isRecordBound = 1;
    end
else
    error('write_dataobj:Assertion', 'zVarValue is neither char nor numeric.')
end

end



% "Normalize" a size vector, i.e. 1D vector describing size (dimensions) of variable. Forces a row vector. Removes
% trailing ones (explicit size one for higher dimensions). Using this makes size vectors easily (and safely) comparable.
%
% NOTE: size() returns all dimensions up until the last non-size-one dimension. This also means that all zero-sized dimensions are included.
%       size() adds trailing ones up to 2D;
%
% []    ==> []  (size 1x0)
% [0]   ==> [0]
% [1 0] ==> [1 0]
% [0 1] ==> [0]
% [1 1] ==> [] (1x0)
function sizeVec = normalize_size_vec(sizeVec)
% IMPLEMENTATION NOTE: sizeVec = [] ==> find returns [] (not a number) ==> 1:[], but that gives the same result as
% 1:0 so the code works anyway.
sizeVec = sizeVec(1:find(sizeVec ~= 1, 1, 'last'));    % "Normalize" size vector.
end



% Handle special case for zero-record zVariables: (1) error, or (2) modify zVarData
% function zVarData = handle_zero_records(zVarData, padValue, specifiedMatlabClass, turnZeroRecordsIntoOneRecord)
% 
% if isempty(zVarData)
%     if ~turnZeroRecordsIntoOneRecord
%         error('write_dataobj:Assertion', 'Can not handle CDF zVariables with zero records (due to presumed bug in spdfcdfwrite).')
%     else
%         %---------------------------------------------------------------------------------------------
%         % EXPERIMENTAL SOLUTION: Store 1 record of data with only pad values instead of zero records.
%         % NOTE: Incomplete since does not take CDF variable type, array dimensions into account.
%         %---------------------------------------------------------------------------------------------
%         nRecords = 1;
%         try
%             zVarData = cast(ones(nRecords, 1), specifiedMatlabClass) * padValue;
%         catch exception
%             error('write_dataobj:Assertion', 'Can not type cast zvar data variable to MATLAB class "%s" (CDF: "%s").', ...
%                 specifiedMatlabClass, dataobjStatedCdfDataType)
%         end
%     end
% end
% 
% end
