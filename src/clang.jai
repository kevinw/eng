
Clang :: #foreign_library "../bin/libclang";

CXTranslationUnitImpl :: struct {}
CXTargetInfoImpl :: struct {}
CXCursorSetImpl :: struct {}

// CXString

CXString :: struct {
    data: *void;
    private_flags: u32;
}

CXStringSet :: struct {
    Strings: *CXString;
    Count: u32;
}

clang_getCString :: (str: CXString) -> *u8 #foreign Clang;
clang_disposeString :: (str: CXString) #foreign Clang;
clang_disposeStringSet :: (str: *CXStringSet) #foreign Clang;

// CXErrorCode

using CXErrorCode :: enum {
    CXError_Success :: 0;
    CXError_Failure :: 1;
    CXError_Crashed :: 2;
    CXError_InvalidArguments :: 3;
    CXError_ASTReadError :: 4;
}

// Index

CINDEX_VERSION_MAJOR :: 0;
CINDEX_VERSION_MINOR :: 49;
CINDEX_VERSION_ENCODE :: (major: $T, minor: T) -> T { return ((major) * 10000) + ((minor) * 1); }
CINDEX_VERSION :: #run CINDEX_VERSION_ENCODE(CINDEX_VERSION_MAJOR, CINDEX_VERSION_MINOR);
CINDEX_VERSION_STRING :: #run sprint("%.%", CINDEX_VERSION_MAJOR, CINDEX_VERSION_MINOR);


CXIndex :: *void;
CXTargetInfo :: *CXTargetInfoImpl;
CXTranslationUnit :: *CXTranslationUnitImpl;
CXClientData :: *void;
CXUnsavedFile :: struct {
    Filename: *u8;
    Contents: *u8;
    Length: u64;
}

using CXAvailabilityKind :: enum {
    CXAvailability_Available;
    CXAvailability_Deprecated;
    CXAvailability_NotAvailable;
    CXAvailability_NotAccessible;
}

CXVersion :: struct {
    Major: s32;
    Minor: s32;
    Subminor: s32;
}

using CXCursor_ExceptionSpecificationKind :: enum {
    CXCursor_ExceptionSpecificationKind_None;
    CXCursor_ExceptionSpecificationKind_DynamicNone;
    CXCursor_ExceptionSpecificationKind_Dynamic;
    CXCursor_ExceptionSpecificationKind_MSAny;
    CXCursor_ExceptionSpecificationKind_BasicNoexcept;
    CXCursor_ExceptionSpecificationKind_ComputedNoexcept;
    CXCursor_ExceptionSpecificationKind_Unevaluated;
    CXCursor_ExceptionSpecificationKind_Uninstantiated;
    CXCursor_ExceptionSpecificationKind_Unparsed;
}

clang_createIndex :: (excludeDeclarationsFromPCH: s32, displayDiagnostics: s32) -> CXIndex #foreign Clang;
clang_disposeIndex :: (index: CXIndex) #foreign Clang;

using CXGlobalOptFlags :: enum {
    CXGlobalOpt_None :: 0x0;
    CXGlobalOpt_ThreadBackgroundPriorityForIndexing :: 0x1;
    CXGlobalOpt_ThreadBackgroundPriorityForEditing :: 0x2;
    CXGlobalOpt_ThreadBackgroundPriorityForAll :: CXGlobalOpt_ThreadBackgroundPriorityForIndexing | CXGlobalOpt_ThreadBackgroundPriorityForEditing;
}

clang_CXIndex_setGlobalOptions :: (index: CXIndex, options: u32) #foreign Clang;
clang_CXIndex_getGlobalOptions :: (index: CXIndex) -> u32 #foreign Clang;
clang_CXIndex_setInvocationEmissionPathOption :: (index: CXIndex, Path: *u8) #foreign Clang;

CXFile :: *void;

clang_getFileName :: (SFile: CXFile) -> CXString #foreign Clang;
clang_getFileTime :: (SFile: CXFile) -> time_t #foreign Clang;

CXFileUniqueID :: struct {
    data: [3] u64;
}

clang_getFileUniqueID :: (file: CXFile, outID: *CXFileUniqueID) -> s32 #foreign Clang;
clang_isFileMultipleIncludeGuarded :: (tu: CXTranslationUnit, file: CXFile) -> u32 #foreign Clang;
clang_getFile :: (tu: CXTranslationUnit, file_name: *u8) -> CXFile #foreign Clang;
clang_getFileContents :: (tu: CXTranslationUnit, file: CXFile, size: *size_t) -> *u8 #foreign Clang;
clang_File_isEqual :: (file1: CXFile, file2: CXFile) -> s32 #foreign Clang;
clang_File_tryGetRealPathName :: (file: CXFile) -> CXString #foreign Clang;

CXSourceLocation :: struct {
    ptr_data: [2] *void;
    int_data: u32;
}

CXSourceRange :: struct {
    ptr_data: [2] *void;
    begin_int_data: u32;
    end_int_data: u32;
}

clang_getNullLocation :: () -> CXSourceLocation #foreign Clang;

clang_equalLocations :: (loc1: CXSourceLocation, loc2: CXSourceLocation) -> u32 #foreign Clang;
clang_getLocation :: (tu: CXTranslationUnit, file: CXFile, line: u32, column: u32) -> CXSourceLocation #foreign Clang;
clang_getLocationForOffset :: (tu: CXTranslationUnit, file: CXFile, offset: u32) -> CXSourceLocation #foreign Clang;
clang_Location_isInSystemHeader :: (location: CXSourceLocation) -> s32 #foreign Clang;
clang_Location_isFromMainFile :: (location: CXSourceLocation) -> s32 #foreign Clang;
clang_getNullRange :: () -> CXSourceRange #foreign Clang;
clang_getRange :: (begin: CXSourceLocation, end: CXSourceLocation) -> CXSourceRange #foreign Clang;
clang_equalRanges :: (range1: CXSourceRange, range2: CXSourceRange) -> u32 #foreign Clang;
clang_Range_isNull :: (range: CXSourceRange) -> s32 #foreign Clang;
clang_getExpansionLocation :: (location: CXSourceLocation, file: *CXFile, line: *u32, column: *u32, offset: *u32) #foreign Clang;
clang_getPresumedLocation :: (location: CXSourceLocation, filename: *CXString, line: *u32, column: *u32) #foreign Clang;
clang_getInstantiationLocation :: (location: CXSourceLocation, file: *CXFile, line: *u32, column: *u32, offset: *u32) #foreign Clang;
clang_getSpellingLocation :: (location: CXSourceLocation, file: *CXFile, line: *u32, column: *u32, offset: *u32) #foreign Clang;
clang_getFileLocation :: (location: CXSourceLocation, file: *CXFile, line: *u32, column: *u32, offset: *u32) #foreign Clang;
clang_getRangeStart :: (range: CXSourceRange) -> CXSourceLocation #foreign Clang;
clang_getRangeEnd :: (range: CXSourceRange) -> CXSourceLocation #foreign Clang;

CXSourceRangeList :: struct {
    count: u32;
    ranges: *CXSourceRange;
}

clang_getSkippedRanges :: (tu: CXTranslationUnit, file: CXFile) -> *CXSourceRangeList #foreign Clang;
clang_getAllSkippedRanges :: (tu: CXTranslationUnit) -> *CXSourceRangeList #foreign Clang;
clang_disposeSourceRangeList :: (ranges: *CXSourceRangeList) #foreign Clang;

using CXDiagnosticSeverity :: enum u32 {
    CXDiagnostic_Ignored :: 0;
    CXDiagnostic_Note    :: 1;
    CXDiagnostic_Warning :: 2;
    CXDiagnostic_Error   :: 3;
    CXDiagnostic_Fatal   :: 4;
}

CXDiagnostic :: *void;
CXDiagnosticSet :: *void;

clang_getNumDiagnosticsInSet :: (Diags: CXDiagnosticSet) -> u32 #foreign Clang;
clang_getDiagnosticInSet :: (Diags: CXDiagnosticSet, Index: u32) -> CXDiagnostic #foreign Clang;  

using CXLoadDiag_Error :: enum {
    CXLoadDiag_None :: 0;
    CXLoadDiag_Unknown :: 1;
    CXLoadDiag_CannotLoad :: 2;
    CXLoadDiag_InvalidFile :: 3;
}

clang_loadDiagnostics :: (file: *u8, error: *CXLoadDiag_Error, errorString: *CXString) -> CXDiagnosticSet #foreign Clang;
clang_disposeDiagnosticSet :: (Diags: CXDiagnosticSet) #foreign Clang;
clang_getChildDiagnostics :: (D: CXDiagnostic) -> CXDiagnosticSet #foreign Clang;
clang_getNumDiagnostics :: (Unit: CXTranslationUnit) -> u32 #foreign Clang;
clang_getDiagnostic :: (Unit: CXTranslationUnit, Index: u32) -> CXDiagnostic #foreign Clang;
clang_getDiagnosticSetFromTU :: (Unit: CXTranslationUnit) -> CXDiagnosticSet #foreign Clang;
clang_disposeDiagnostic :: (Diagnostic: CXDiagnostic) #foreign Clang;

using CXDiagnosticDisplayOptions :: enum {
    CXDiagnostic_DisplaySourceLocation :: 0x01;
    CXDiagnostic_DisplayColumn :: 0x02;
    CXDiagnostic_DisplaySourceRanges :: 0x04;
    CXDiagnostic_DisplayOption :: 0x08;
    CXDiagnostic_DisplayCategoryId :: 0x10;
    CXDiagnostic_DisplayCategoryName :: 0x20;
}

clang_formatDiagnostic :: (Diagnostic: CXDiagnostic, Options: u32) -> CXString #foreign Clang;
clang_defaultDiagnosticDisplayOptions :: () -> u32 #foreign Clang;
clang_getDiagnosticSeverity :: (D: CXDiagnostic) -> CXDiagnosticSeverity #foreign Clang;
clang_getDiagnosticLocation :: (D: CXDiagnostic) -> CXSourceLocation #foreign Clang;
clang_getDiagnosticSpelling :: (D: CXDiagnostic) -> CXString #foreign Clang;
clang_getDiagnosticOption :: (Diag: CXDiagnostic, Disable: *CXString) -> CXString #foreign Clang;
clang_getDiagnosticCategory :: (D: CXDiagnostic) -> u32 #foreign Clang;
clang_getDiagnosticCategoryName :: (Category: u32) -> CXString #foreign Clang #deprecated;
clang_getDiagnosticCategoryText :: (D: CXDiagnostic) -> CXString #foreign Clang;
clang_getDiagnosticNumRanges :: (D: CXDiagnostic) -> u32 #foreign Clang;
clang_getDiagnosticRange :: (Diagnostic: CXDiagnostic, Range: u32) -> CXSourceRange #foreign Clang;
clang_getDiagnosticNumFixIts :: (Diagnostic: CXDiagnostic) -> u32 #foreign Clang;
clang_getDiagnosticFixIt :: (Diagnostic: CXDiagnostic, FixIt: u32, ReplacementRange: *CXSourceRange) -> CXString #foreign Clang;
clang_getTranslationUnitSpelling :: (CTUnit: CXTranslationUnit) -> CXString #foreign Clang;
clang_createTranslationUnitFromSourceFile :: (CIdx: CXIndex, source_filename: *u8, num_clang_command_line_args: s32, clang_command_line_args: **u8, num_unsaved_files: u32, unsaved_files: *CXUnsavedFile) -> CXTranslationUnit #foreign Clang;
clang_createTranslationUnit :: (CIdx: CXIndex, ast_filename: *u8) -> CXTranslationUnit #foreign Clang;
clang_createTranslationUnit2 :: (CIdx: CXIndex, ast_filename: *u8, out_TU: *CXTranslationUnit) -> CXErrorCode #foreign Clang;

using CXTranslationUnit_Flags :: enum u32 {
    CXTranslationUnit_None :: 0x0;
    CXTranslationUnit_DetailedPreprocessingRecord :: 0x01;
    CXTranslationUnit_Incomplete :: 0x02;
    CXTranslationUnit_PrecompiledPreamble :: 0x04;
    CXTranslationUnit_CacheCompletionResults :: 0x08;
    CXTranslationUnit_ForSerialization :: 0x10;
    CXTranslationUnit_CXXChainedPCH :: 0x20;
    CXTranslationUnit_SkipFunctionBodies :: 0x40;
    CXTranslationUnit_IncludeBriefCommentsInCodeCompletion :: 0x80;
    CXTranslationUnit_CreatePreambleOnFirstParse :: 0x100;
    CXTranslationUnit_KeepGoing :: 0x200;
    CXTranslationUnit_SingleFileParse :: 0x400;
    CXTranslationUnit_LimitSkipFunctionBodiesToPreamble :: 0x800;
}

clang_defaultEditingTranslationUnitOptions :: () -> u32 #foreign Clang;
clang_parseTranslationUnit :: (CIdx: CXIndex, source_filename: *u8, command_line_args: **u8, num_command_line_args: s32, unsaved_files: *CXUnsavedFile, num_unsaved_files: u32, options: CXTranslationUnit_Flags) -> CXTranslationUnit #foreign Clang;
clang_parseTranslationUnit2 :: (CIdx: CXIndex, source_filename: *u8, command_line_args: **u8, num_command_line_args: s32, unsaved_files: *CXUnsavedFile, num_unsaved_files: u32, options: CXTranslationUnit_Flags, out_TU: *CXTranslationUnit) -> CXErrorCode #foreign Clang;
clang_parseTranslationUnit2FullArgv :: (CIdx: CXIndex, source_filename: *u8, command_line_args: **u8, num_command_line_args: s32, unsaved_files: *CXUnsavedFile, num_unsaved_files: u32, options: CXTranslationUnit_Flags, out_TU: *CXTranslationUnit) -> CXErrorCode #foreign Clang;

using CXSaveTranslationUnit_Flags :: enum {
    CXSaveTranslationUnit_None :: 0x0;
}

clang_defaultSaveOptions :: (TU: CXTranslationUnit) -> u32 #foreign Clang;

using CXSaveError :: enum s32 {
    CXSaveError_None :: 0;
    CXSaveError_Unknown :: 1;
    CXSaveError_TranslationErrors :: 2;
    CXSaveError_InvalidTU :: 3;

}

clang_saveTranslationUnit :: (TU: CXTranslationUnit, FileName: *u8, options: CXTranslationUnit_Flags) -> CXSaveError #foreign Clang;
clang_suspendTranslationUnit :: (TU: CXTranslationUnit) -> u32 #foreign Clang;
clang_disposeTranslationUnit :: (TU: CXTranslationUnit) #foreign Clang;

using CXReparse_Flags :: enum {
    CXReparse_None :: 0x0;
}

clang_defaultReparseOptions :: (TU: CXTranslationUnit) -> u32 #foreign Clang;
clang_reparseTranslationUnit :: (TU: CXTranslationUnit, num_unsaved_files: u32, unsaved_files: *CXUnsavedFile, options: u32) -> s32 #foreign Clang;

using CXTUResourceUsageKind :: enum {
    CXTUResourceUsage_AST :: 1;
    CXTUResourceUsage_Identifiers :: 2;
    CXTUResourceUsage_Selectors :: 3;
    CXTUResourceUsage_GlobalCompletionResults :: 4;
    CXTUResourceUsage_SourceManagerContentCache :: 5;
    CXTUResourceUsage_AST_SideTables :: 6;
    CXTUResourceUsage_SourceManager_Membuffer_Malloc :: 7;
    CXTUResourceUsage_SourceManager_Membuffer_MMap :: 8;
    CXTUResourceUsage_ExternalASTSource_Membuffer_Malloc :: 9;
    CXTUResourceUsage_ExternalASTSource_Membuffer_MMap :: 10;
    CXTUResourceUsage_Preprocessor :: 11;
    CXTUResourceUsage_PreprocessingRecord :: 12;
    CXTUResourceUsage_SourceManager_DataStructures :: 13;
    CXTUResourceUsage_Preprocessor_HeaderSearch :: 14;
    CXTUResourceUsage_MEMORY_IN_BYTES_BEGIN :: CXTUResourceUsage_AST;
    CXTUResourceUsage_MEMORY_IN_BYTES_END :: CXTUResourceUsage_Preprocessor_HeaderSearch;
    CXTUResourceUsage_First :: CXTUResourceUsage_AST;
    CXTUResourceUsage_Last :: CXTUResourceUsage_Preprocessor_HeaderSearch;
}

clang_getTUResourceUsageName :: (kind: CXTUResourceUsageKind) -> *u8 #foreign Clang;

CXTUResourceUsageEntry :: struct {
    kind: CXTUResourceUsageKind;  
    amount: u64;
}

CXTUResourceUsage :: struct {
    data: *void;
    numEntries: u32;
    entries: *CXTUResourceUsageEntry;
}

clang_getCXTUResourceUsage :: (TU: CXTranslationUnit) -> CXTUResourceUsage #foreign Clang;
clang_disposeCXTUResourceUsage :: (usage: CXTUResourceUsage) #foreign Clang;
clang_getTranslationUnitTargetInfo :: (CTUnit: CXTranslationUnit) -> CXTargetInfo #foreign Clang;
clang_TargetInfo_dispose :: (Info: CXTargetInfo) #foreign Clang;
clang_TargetInfo_getTriple :: (Info: CXTargetInfo) -> CXString #foreign Clang;
clang_TargetInfo_getPointerWidth :: (Info: CXTargetInfo) -> s32 #foreign Clang;

using CXCursorKind :: enum {
    CXCursor_UnexposedDecl                 :: 1;
    CXCursor_StructDecl                    :: 2;
    CXCursor_UnionDecl                     :: 3;
    CXCursor_ClassDecl                     :: 4;
    CXCursor_EnumDecl                      :: 5;
    CXCursor_FieldDecl                     :: 6;
    CXCursor_EnumConstantDecl              :: 7;
    CXCursor_FunctionDecl                  :: 8;
    CXCursor_VarDecl                       :: 9;
    CXCursor_ParmDecl                      :: 10;
    CXCursor_ObjCInterfaceDecl             :: 11;
    CXCursor_ObjCCategoryDecl              :: 12;
    CXCursor_ObjCProtocolDecl              :: 13;
    CXCursor_ObjCPropertyDecl              :: 14;
    CXCursor_ObjCIvarDecl                  :: 15;
    CXCursor_ObjCInstanceMethodDecl        :: 16;
    CXCursor_ObjCClassMethodDecl           :: 17;
    CXCursor_ObjCImplementationDecl        :: 18;
    CXCursor_ObjCCategoryImplDecl          :: 19;
    CXCursor_TypedefDecl                   :: 20;
    CXCursor_CXXMethod                     :: 21;
    CXCursor_Namespace                     :: 22;
    CXCursor_LinkageSpec                   :: 23;
    CXCursor_Constructor                   :: 24;
    CXCursor_Destructor                    :: 25;
    CXCursor_ConversionFunction            :: 26;
    CXCursor_TemplateTypeParameter         :: 27;
    CXCursor_NonTypeTemplateParameter      :: 28;
    CXCursor_TemplateTemplateParameter     :: 29;
    CXCursor_FunctionTemplate              :: 30;
    CXCursor_ClassTemplate                 :: 31;
    CXCursor_ClassTemplatePartialSpecialization :: 32;
    CXCursor_NamespaceAlias                :: 33;
    CXCursor_UsingDirective                :: 34;
    CXCursor_UsingDeclaration              :: 35;
    CXCursor_TypeAliasDecl                 :: 36;
    CXCursor_ObjCSynthesizeDecl            :: 37;
    CXCursor_ObjCDynamicDecl               :: 38;
    CXCursor_CXXAccessSpecifier            :: 39;
    CXCursor_FirstDecl                     :: CXCursor_UnexposedDecl;
    CXCursor_LastDecl                      :: CXCursor_CXXAccessSpecifier;
    CXCursor_FirstRef                      :: 40;
    CXCursor_ObjCSuperClassRef             :: 40;
    CXCursor_ObjCProtocolRef               :: 41;
    CXCursor_ObjCClassRef                  :: 42;
    CXCursor_TypeRef                       :: 43;
    CXCursor_CXXBaseSpecifier              :: 44;
    CXCursor_TemplateRef                   :: 45;
    CXCursor_NamespaceRef                  :: 46;
    CXCursor_MemberRef                     :: 47;
    CXCursor_LabelRef                      :: 48;
    CXCursor_OverloadedDeclRef             :: 49;
    CXCursor_VariableRef                   :: 50;
    CXCursor_LastRef                       :: CXCursor_VariableRef;
    CXCursor_FirstInvalid                  :: 70;
    CXCursor_InvalidFile                   :: 70;
    CXCursor_NoDeclFound                   :: 71;
    CXCursor_NotImplemented                :: 72;
    CXCursor_InvalidCode                   :: 73;
    CXCursor_LastInvalid                   :: CXCursor_InvalidCode;
    CXCursor_FirstExpr                     :: 100;
    CXCursor_UnexposedExpr                 :: 100;
    CXCursor_DeclRefExpr                   :: 101;
    CXCursor_MemberRefExpr                 :: 102;
    CXCursor_CallExpr                      :: 103;
    CXCursor_ObjCMessageExpr               :: 104;
    CXCursor_BlockExpr                     :: 105;
    CXCursor_IntegerLiteral                :: 106;
    CXCursor_FloatingLiteral               :: 107;
    CXCursor_ImaginaryLiteral              :: 108;
    CXCursor_StringLiteral                 :: 109;
    CXCursor_CharacterLiteral              :: 110;
    CXCursor_ParenExpr                     :: 111;
    CXCursor_UnaryOperator                 :: 112;
    CXCursor_ArraySubscriptExpr            :: 113;
    CXCursor_BinaryOperator                :: 114;
    CXCursor_CompoundAssignOperator        :: 115;
    CXCursor_ConditionalOperator           :: 116;
    CXCursor_CStyleCastExpr                :: 117;
    CXCursor_CompoundLiteralExpr           :: 118;
    CXCursor_InitListExpr                  :: 119;
    CXCursor_AddrLabelExpr                 :: 120;
    CXCursor_StmtExpr                      :: 121;
    CXCursor_GenericSelectionExpr          :: 122;
    CXCursor_GNUNullExpr                   :: 123;
    CXCursor_CXXStaticCastExpr             :: 124;
    CXCursor_CXXDynamicCastExpr            :: 125;
    CXCursor_CXXReinterpretCastExpr        :: 126;
    CXCursor_CXXConstCastExpr              :: 127;
    CXCursor_CXXFunctionalCastExpr         :: 128;
    CXCursor_CXXTypeidExpr                 :: 129;
    CXCursor_CXXBoolLiteralExpr            :: 130;
    CXCursor_CXXNullPtrLiteralExpr         :: 131;
    CXCursor_CXXThisExpr                   :: 132;
    CXCursor_CXXThrowExpr                  :: 133;
    CXCursor_CXXNewExpr                    :: 134;
    CXCursor_CXXDeleteExpr                 :: 135;
    CXCursor_UnaryExpr                     :: 136;
    CXCursor_ObjCStringLiteral             :: 137;
    CXCursor_ObjCEncodeExpr                :: 138;
    CXCursor_ObjCSelectorExpr              :: 139;
    CXCursor_ObjCProtocolExpr              :: 140;
    CXCursor_ObjCBridgedCastExpr           :: 141;
    CXCursor_PackExpansionExpr             :: 142;
    CXCursor_SizeOfPackExpr                :: 143;
    CXCursor_LambdaExpr                    :: 144;
    CXCursor_ObjCBoolLiteralExpr           :: 145;
    CXCursor_ObjCSelfExpr                  :: 146;
    CXCursor_OMPArraySectionExpr           :: 147;
    CXCursor_ObjCAvailabilityCheckExpr     :: 148;
    CXCursor_FixedPointLiteral             :: 149;
    CXCursor_LastExpr                      :: CXCursor_FixedPointLiteral;
    CXCursor_FirstStmt                     :: 200;
    CXCursor_UnexposedStmt                 :: 200;
    CXCursor_LabelStmt                     :: 201;
    CXCursor_CompoundStmt                  :: 202;
    CXCursor_CaseStmt                      :: 203;
    CXCursor_DefaultStmt                   :: 204;
    CXCursor_IfStmt                        :: 205;
    CXCursor_SwitchStmt                    :: 206;
    CXCursor_WhileStmt                     :: 207;
    CXCursor_DoStmt                        :: 208;
    CXCursor_ForStmt                       :: 209;
    CXCursor_GotoStmt                      :: 210;
    CXCursor_IndirectGotoStmt              :: 211;
    CXCursor_ContinueStmt                  :: 212;
    CXCursor_BreakStmt                     :: 213;
    CXCursor_ReturnStmt                    :: 214;
    CXCursor_GCCAsmStmt                    :: 215;
    CXCursor_AsmStmt                       :: CXCursor_GCCAsmStmt;
    CXCursor_ObjCAtTryStmt                 :: 216;
    CXCursor_ObjCAtCatchStmt               :: 217;
    CXCursor_ObjCAtFinallyStmt             :: 218;
    CXCursor_ObjCAtThrowStmt               :: 219;
    CXCursor_ObjCAtSynchronizedStmt        :: 220;
    CXCursor_ObjCAutoreleasePoolStmt       :: 221;
    CXCursor_ObjCForCollectionStmt         :: 222;
    CXCursor_CXXCatchStmt                  :: 223;
    CXCursor_CXXTryStmt                    :: 224;
    CXCursor_CXXForRangeStmt               :: 225;
    CXCursor_SEHTryStmt                    :: 226;
    CXCursor_SEHExceptStmt                 :: 227;
    CXCursor_SEHFinallyStmt                :: 228;
    CXCursor_MSAsmStmt                     :: 229;
    CXCursor_NullStmt                      :: 230;
    CXCursor_DeclStmt                      :: 231;
    CXCursor_OMPParallelDirective          :: 232;
    CXCursor_OMPSimdDirective              :: 233;
    CXCursor_OMPForDirective               :: 234;
    CXCursor_OMPSectionsDirective          :: 235;
    CXCursor_OMPSectionDirective           :: 236;
    CXCursor_OMPSingleDirective            :: 237;
    CXCursor_OMPParallelForDirective       :: 238;
    CXCursor_OMPParallelSectionsDirective  :: 239;
    CXCursor_OMPTaskDirective              :: 240;
    CXCursor_OMPMasterDirective            :: 241;
    CXCursor_OMPCriticalDirective          :: 242;
    CXCursor_OMPTaskyieldDirective         :: 243;
    CXCursor_OMPBarrierDirective           :: 244;
    CXCursor_OMPTaskwaitDirective          :: 245;
    CXCursor_OMPFlushDirective             :: 246;
    CXCursor_SEHLeaveStmt                  :: 247;
    CXCursor_OMPOrderedDirective           :: 248;
    CXCursor_OMPAtomicDirective            :: 249;
    CXCursor_OMPForSimdDirective           :: 250;
    CXCursor_OMPParallelForSimdDirective   :: 251;
    CXCursor_OMPTargetDirective            :: 252;
    CXCursor_OMPTeamsDirective             :: 253;
    CXCursor_OMPTaskgroupDirective         :: 254;
    CXCursor_OMPCancellationPointDirective :: 255;
    CXCursor_OMPCancelDirective            :: 256;
    CXCursor_OMPTargetDataDirective        :: 257;
    CXCursor_OMPTaskLoopDirective          :: 258;
    CXCursor_OMPTaskLoopSimdDirective      :: 259;
    CXCursor_OMPDistributeDirective        :: 260;
    CXCursor_OMPTargetEnterDataDirective   :: 261;
    CXCursor_OMPTargetExitDataDirective    :: 262;
    CXCursor_OMPTargetParallelDirective    :: 263;
    CXCursor_OMPTargetParallelForDirective :: 264;
    CXCursor_OMPTargetUpdateDirective      :: 265;
    CXCursor_OMPDistributeParallelForDirective :: 266;
    CXCursor_OMPDistributeParallelForSimdDirective :: 267;
    CXCursor_OMPDistributeSimdDirective :: 268;
    CXCursor_OMPTargetParallelForSimdDirective :: 269;
    CXCursor_OMPTargetSimdDirective :: 270;
    CXCursor_OMPTeamsDistributeDirective :: 271;
    CXCursor_OMPTeamsDistributeSimdDirective :: 272;
    CXCursor_OMPTeamsDistributeParallelForSimdDirective :: 273;
    CXCursor_OMPTeamsDistributeParallelForDirective :: 274;
    CXCursor_OMPTargetTeamsDirective :: 275;
    CXCursor_OMPTargetTeamsDistributeDirective :: 276;
    CXCursor_OMPTargetTeamsDistributeParallelForDirective :: 277;
    CXCursor_OMPTargetTeamsDistributeParallelForSimdDirective :: 278;
    CXCursor_OMPTargetTeamsDistributeSimdDirective :: 279;
    CXCursor_LastStmt :: CXCursor_OMPTargetTeamsDistributeSimdDirective;
    CXCursor_TranslationUnit               :: 300;
    CXCursor_FirstAttr                     :: 400;
    CXCursor_UnexposedAttr                 :: 400;
    CXCursor_IBActionAttr                  :: 401;
    CXCursor_IBOutletAttr                  :: 402;
    CXCursor_IBOutletCollectionAttr        :: 403;
    CXCursor_CXXFinalAttr                  :: 404;
    CXCursor_CXXOverrideAttr               :: 405;
    CXCursor_AnnotateAttr                  :: 406;
    CXCursor_AsmLabelAttr                  :: 407;
    CXCursor_PackedAttr                    :: 408;
    CXCursor_PureAttr                      :: 409;
    CXCursor_ConstAttr                     :: 410;
    CXCursor_NoDuplicateAttr               :: 411;
    CXCursor_CUDAConstantAttr              :: 412;
    CXCursor_CUDADeviceAttr                :: 413;
    CXCursor_CUDAGlobalAttr                :: 414;
    CXCursor_CUDAHostAttr                  :: 415;
    CXCursor_CUDASharedAttr                :: 416;
    CXCursor_VisibilityAttr                :: 417;
    CXCursor_DLLExport                     :: 418;
    CXCursor_DLLImport                     :: 419;
    CXCursor_LastAttr                      :: CXCursor_DLLImport;
    CXCursor_PreprocessingDirective        :: 500;
    CXCursor_MacroDefinition               :: 501;
    CXCursor_MacroExpansion                :: 502;
    CXCursor_MacroInstantiation            :: CXCursor_MacroExpansion;
    CXCursor_InclusionDirective            :: 503;
    CXCursor_FirstPreprocessing            :: CXCursor_PreprocessingDirective;
    CXCursor_LastPreprocessing             :: CXCursor_InclusionDirective;
    CXCursor_ModuleImportDecl              :: 600;
    CXCursor_TypeAliasTemplateDecl         :: 601;
    CXCursor_StaticAssert                  :: 602;
    CXCursor_FriendDecl                    :: 603;
    CXCursor_FirstExtraDecl                :: CXCursor_ModuleImportDecl;
    CXCursor_LastExtraDecl                 :: CXCursor_FriendDecl;
    CXCursor_OverloadCandidate             :: 700;
}

CXCursor :: struct {
    kind: CXCursorKind;
    xdata: s32;
    data: [3] *void;
}

clang_getNullCursor :: () -> CXCursor #foreign Clang;
clang_getTranslationUnitCursor :: (TU: CXTranslationUnit) -> CXCursor #foreign Clang;
clang_equalCursors :: (cur1: CXCursor, cur2: CXCursor) -> u32 #foreign Clang;
clang_Cursor_isNull :: (cursor: CXCursor) -> s32 #foreign Clang;
clang_hashCursor :: (cur: CXCursor) -> u32 #foreign Clang;
clang_getCursorKind :: (cur: CXCursor) -> CXCursorKind #foreign Clang;
clang_isDeclaration :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isInvalidDeclaration :: (kind: CXCursor) -> u32 #foreign Clang;
clang_isReference :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isExpression :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isStatement :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isAttribute :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_Cursor_hasAttrs :: (C: CXCursor) -> u32 #foreign Clang;
clang_isInvalid :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isTranslationUnit :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isPreprocessing :: (kind: CXCursorKind) -> u32 #foreign Clang;
clang_isUnexposed :: (kind: CXCursorKind) -> u32 #foreign Clang;

using CXLinkageKind :: enum {
    CXLinkage_Invalid;
    CXLinkage_NoLinkage;
    CXLinkage_Internal;
    CXLinkage_UniqueExternal;
    CXLinkage_External;
}

clang_getCursorLinkage :: (cursor: CXCursor) -> CXLinkageKind #foreign Clang;

using CXVisibilityKind :: enum {
  CXVisibility_Invalid;
  CXVisibility_Hidden;
  CXVisibility_Protected;
  CXVisibility_Default;
}

clang_getCursorVisibility :: (cursor: CXCursor) -> CXVisibilityKind #foreign Clang;
clang_getCursorAvailability :: (cursor: CXCursor) -> CXAvailabilityKind #foreign Clang;

CXPlatformAvailability :: struct {
    Platform: CXString;
    Introduced: CXVersion;
    Deprecated: CXVersion;
    Obsoleted: CXVersion;
    Unavailable: s32;
    Message: CXString;
}

clang_getCursorPlatformAvailability :: (cursor: CXCursor, always_deprecated: *s32, deprecated_message: *CXString,
                                        always_unavailable: *s32, unavailable_message: *CXString,
                                        availability: *CXPlatformAvailability, availability_size: s32) -> s32 #foreign Clang;

clang_disposeCXPlatformAvailability :: (availability: *CXPlatformAvailability) #foreign Clang;

using CXLanguageKind :: enum {
    CXLanguage_Invalid :: 0;
    CXLanguage_C;
    CXLanguage_ObjC;
    CXLanguage_CPlusPlus;
}

clang_getCursorLanguage :: (cursor: CXCursor) -> CXLanguageKind #foreign Clang;

using CXTLSKind :: enum {
    CXTLS_None :: 0;
    CXTLS_Dynamic;
    CXTLS_Static;
}

clang_getCursorTLSKind :: (cursor: CXCursor) -> CXTLSKind #foreign Clang;
clang_Cursor_getTranslationUnit :: (C: CXCursor) -> CXTranslationUnit #foreign Clang;

CXCursorSet :: *CXCursorSetImpl;

clang_createCXCursorSet :: () -> CXCursorSet #foreign Clang;
clang_disposeCXCursorSet :: (cset: CXCursorSet) #foreign Clang;
clang_CXCursorSet_contains :: (cset: CXCursorSet, cursor:CXCursor) -> u32 #foreign Clang;
clang_CXCursorSet_insert :: (cset: CXCursorSet, cursor: CXCursor) -> u32 #foreign Clang;
clang_getCursorSemanticParent :: (cursor: CXCursor) -> CXCursor #foreign Clang;
clang_getCursorLexicalParent :: (cursor: CXCursor) -> CXCursor #foreign Clang;
clang_getOverriddenCursors :: (cursor: CXCursor, overridden: **CXCursor, num_overridden: *u32) #foreign Clang;
clang_disposeOverriddenCursors :: (overridden: *CXCursor) #foreign Clang;
clang_getIncludedFile :: (cursor: CXCursor) -> CXFile #foreign Clang;
clang_getCursor :: (tu: CXTranslationUnit, loc: CXSourceLocation) -> CXCursor #foreign Clang;
clang_getCursorLocation :: (cursor: CXCursor) -> CXSourceLocation #foreign Clang;
clang_getCursorExtent :: (cursor: CXCursor) -> CXSourceRange #foreign Clang;

using CXTypeKind :: enum u32 {
    CXType_Invalid :: 0;
    CXType_Unexposed :: 1;
    CXType_Void :: 2;
    CXType_Bool :: 3;
    CXType_Char_U :: 4;
    CXType_UChar :: 5;
    CXType_Char16 :: 6;
    CXType_Char32 :: 7;
    CXType_UShort :: 8;
    CXType_UInt :: 9;
    CXType_ULong :: 10;
    CXType_ULongLong :: 11;
    CXType_UInt128 :: 12;
    CXType_Char_S :: 13;
    CXType_SChar :: 14;
    CXType_WChar :: 15;
    CXType_Short :: 16;
    CXType_Int :: 17;
    CXType_Long :: 18;
    CXType_LongLong :: 19;
    CXType_Int128 :: 20;
    CXType_Float :: 21;
    CXType_Double :: 22;
    CXType_LongDouble :: 23;
    CXType_NullPtr :: 24;
    CXType_Overload :: 25;
    CXType_Dependent :: 26;
    CXType_ObjCId :: 27;
    CXType_ObjCClass :: 28;
    CXType_ObjCSel :: 29;
    CXType_Float128 :: 30;
    CXType_Half :: 31;
    CXType_Float16 :: 32;
    CXType_ShortAccum :: 33;
    CXType_Accum :: 34;
    CXType_LongAccum :: 35;
    CXType_UShortAccum :: 36;
    CXType_UAccum :: 37;
    CXType_ULongAccum :: 38;
    CXType_FirstBuiltin :: CXType_Void;
    CXType_LastBuiltin :: CXType_ULongAccum;
    CXType_Complex :: 100;
    CXType_Pointer :: 101;
    CXType_BlockPointer :: 102;
    CXType_LValueReference :: 103;
    CXType_RValueReference :: 104;
    CXType_Record :: 105;
    CXType_Enum :: 106;
    CXType_Typedef :: 107;
    CXType_ObjCInterface :: 108;
    CXType_ObjCObjectPointer :: 109;
    CXType_FunctionNoProto :: 110;
    CXType_FunctionProto :: 111;
    CXType_ConstantArray :: 112;
    CXType_Vector :: 113;
    CXType_IncompleteArray :: 114;
    CXType_VariableArray :: 115;
    CXType_DependentSizedArray :: 116;
    CXType_MemberPointer :: 117;
    CXType_Auto :: 118;
    CXType_Elaborated :: 119;
    CXType_Pipe :: 120;
    CXType_OCLImage1dRO :: 121;
    CXType_OCLImage1dArrayRO :: 122;
    CXType_OCLImage1dBufferRO :: 123;
    CXType_OCLImage2dRO :: 124;
    CXType_OCLImage2dArrayRO :: 125;
    CXType_OCLImage2dDepthRO :: 126;
    CXType_OCLImage2dArrayDepthRO :: 127;
    CXType_OCLImage2dMSAARO :: 128;
    CXType_OCLImage2dArrayMSAARO :: 129;
    CXType_OCLImage2dMSAADepthRO :: 130;
    CXType_OCLImage2dArrayMSAADepthRO :: 131;
    CXType_OCLImage3dRO :: 132;
    CXType_OCLImage1dWO :: 133;
    CXType_OCLImage1dArrayWO :: 134;
    CXType_OCLImage1dBufferWO :: 135;
    CXType_OCLImage2dWO :: 136;
    CXType_OCLImage2dArrayWO :: 137;
    CXType_OCLImage2dDepthWO :: 138;
    CXType_OCLImage2dArrayDepthWO :: 139;
    CXType_OCLImage2dMSAAWO :: 140;
    CXType_OCLImage2dArrayMSAAWO :: 141;
    CXType_OCLImage2dMSAADepthWO :: 142;
    CXType_OCLImage2dArrayMSAADepthWO :: 143;
    CXType_OCLImage3dWO :: 144;
    CXType_OCLImage1dRW :: 145;
    CXType_OCLImage1dArrayRW :: 146;
    CXType_OCLImage1dBufferRW :: 147;
    CXType_OCLImage2dRW :: 148;
    CXType_OCLImage2dArrayRW :: 149;
    CXType_OCLImage2dDepthRW :: 150;
    CXType_OCLImage2dArrayDepthRW :: 151;
    CXType_OCLImage2dMSAARW :: 152;
    CXType_OCLImage2dArrayMSAARW :: 153;
    CXType_OCLImage2dMSAADepthRW :: 154;
    CXType_OCLImage2dArrayMSAADepthRW :: 155;
    CXType_OCLImage3dRW :: 156;
    CXType_OCLSampler :: 157;
    CXType_OCLEvent :: 158;
    CXType_OCLQueue :: 159;
    CXType_OCLReserveID :: 160;
}

using CXCallingConv :: enum {
    CXCallingConv_Default :: 0;
    CXCallingConv_C :: 1;
    CXCallingConv_X86StdCall :: 2;
    CXCallingConv_X86FastCall :: 3;
    CXCallingConv_X86ThisCall :: 4;
    CXCallingConv_X86Pascal :: 5;
    CXCallingConv_AAPCS :: 6;
    CXCallingConv_AAPCS_VFP :: 7;
    CXCallingConv_X86RegCall :: 8;
    CXCallingConv_IntelOclBicc :: 9;
    CXCallingConv_Win64 :: 10;
    CXCallingConv_X86_64Win64 :: CXCallingConv_Win64;
    CXCallingConv_X86_64SysV :: 11;
    CXCallingConv_X86VectorCall :: 12;
    CXCallingConv_Swift :: 13;
    CXCallingConv_PreserveMost :: 14;
    CXCallingConv_PreserveAll :: 15;
    CXCallingConv_Invalid :: 100;
    CXCallingConv_Unexposed :: 200;
}

CXType :: struct {
  kind: CXTypeKind;
  data: [2] *void;
}

clang_getCursorType :: (C: CXCursor) -> CXType #foreign Clang;
clang_getTypeSpelling :: (CT: CXType) -> CXString #foreign Clang;
clang_getTypedefDeclUnderlyingType :: (C: CXCursor) -> CXType #foreign Clang;
clang_getEnumDeclIntegerType :: (C: CXCursor) -> CXType #foreign Clang;
clang_getEnumConstantDeclValue :: (C: CXCursor) -> s64 #foreign Clang;
clang_getEnumConstantDeclUnsignedValue :: (C: CXCursor) -> u64 #foreign Clang;
clang_getFieldDeclBitWidth :: (C: CXCursor) -> s32 #foreign Clang;
clang_Cursor_getNumArguments :: (C: CXCursor) -> s32 #foreign Clang;
clang_Cursor_getArgument :: (C: CXCursor, i: u32) -> CXCursor #foreign Clang;

CXTemplateArgumentKind :: enum {
    CXTemplateArgumentKind_Null;
    CXTemplateArgumentKind_Type;
    CXTemplateArgumentKind_Declaration;
    CXTemplateArgumentKind_NullPtr;
    CXTemplateArgumentKind_Integral;
    CXTemplateArgumentKind_Template;
    CXTemplateArgumentKind_TemplateExpansion;
    CXTemplateArgumentKind_Expression;
    CXTemplateArgumentKind_Pack;
    CXTemplateArgumentKind_Invalid;
}

clang_Cursor_getNumTemplateArguments :: (C: CXCursor) -> s32 #foreign Clang;
clang_Cursor_getTemplateArgumentKind :: (C: CXCursor, I: u32) -> CXTemplateArgumentKind #foreign Clang;
clang_Cursor_getTemplateArgumentType :: (C: CXCursor, I: u32) -> CXType #foreign Clang;
clang_Cursor_getTemplateArgumentValue :: (C: CXCursor, I: u32) -> s64 #foreign Clang;
clang_Cursor_getTemplateArgumentUnsignedValue :: (C: CXCursor, I: u32) -> u64 #foreign Clang;
clang_equalTypes :: (A: CXType, B: CXType) -> u32 #foreign Clang;
clang_getCanonicalType :: (T: CXType) -> CXType #foreign Clang;
clang_isConstQualifiedType :: (T: CXType) -> u32 #foreign Clang;
clang_Cursor_isMacroFunctionLike :: (C: CXCursor) -> u32 #foreign Clang;
clang_Cursor_isMacroBuiltin :: (C: CXCursor) -> u32 #foreign Clang;
clang_Cursor_isFunctionInlined :: (C: CXCursor) -> u32 #foreign Clang;
clang_isVolatileQualifiedType :: (T: CXType) -> u32 #foreign Clang;
clang_isRestrictQualifiedType :: (T: CXType) -> u32 #foreign Clang;
clang_getAddressSpace :: (T: CXType) -> u32 #foreign Clang;
clang_getTypedefName :: (CT: CXType) -> CXString #foreign Clang;
clang_getPointeeType :: (T: CXType) -> CXType #foreign Clang;
clang_getTypeDeclaration :: (T: CXType) -> CXCursor #foreign Clang;
clang_getDeclObjCTypeEncoding :: (C: CXCursor) -> CXString #foreign Clang;
clang_Type_getObjCEncoding :: (type: CXType) -> CXString #foreign Clang; 
clang_getTypeKindSpelling :: (K: CXTypeKind) -> CXString #foreign Clang;
clang_getFunctionTypeCallingConv :: (T: CXType) -> CXCallingConv #foreign Clang;
clang_getResultType :: (T: CXType) -> CXType #foreign Clang;
clang_getExceptionSpecificationType :: (T: CXType) -> s32 #foreign Clang;
clang_getNumArgTypes :: (T: CXType) -> s32 #foreign Clang;
clang_getArgType :: (T: CXType, i: u32) -> CXType #foreign Clang;
clang_isFunctionTypeVariadic :: (T: CXType) -> u32 #foreign Clang;
clang_getCursorResultType :: (C: CXCursor) -> CXType #foreign Clang;
clang_getCursorExceptionSpecificationType :: (C: CXCursor) -> s32 #foreign Clang;
clang_isPODType :: (T: CXType) -> u32 #foreign Clang;
clang_getElementType :: (T: CXType) -> CXType #foreign Clang;
clang_getNumElements :: (t: CXType) -> s64 #foreign Clang;
clang_getArrayElementType :: (T: CXType) -> CXType #foreign Clang;
clang_getArraySize :: (T: CXType) -> s64 #foreign Clang;
clang_Type_getNamedType :: (T: CXType) -> CXType #foreign Clang;
clang_Type_isTransparentTagTypedef :: (T: CXType) -> u32 #foreign Clang;

using CXTypeLayoutError :: enum {
    CXTypeLayoutError_Invalid :: -1;
    CXTypeLayoutError_Incomplete :: -2;
    CXTypeLayoutError_Dependent :: -3;
    CXTypeLayoutError_NotConstantSize :: -4;
    CXTypeLayoutError_InvalidFieldName :: -5;
}

clang_Type_getAlignOf :: (T: CXType) -> s64 #foreign Clang;
clang_Type_getClassType :: (T: CXType) -> CXType #foreign Clang;
clang_Type_getSizeOf :: (T: CXType) -> s64 #foreign Clang;
clang_Type_getOffsetOf :: (T: CXType, S: *u8) -> s64 #foreign Clang;
clang_Cursor_getOffsetOfField :: (C: CXCursor) -> s64 #foreign Clang;
clang_Cursor_isAnonymous :: (C: CXCursor) -> s32 #foreign Clang;

using CXRefQualifierKind :: enum {
    CXRefQualifier_None :: 0;
    CXRefQualifier_LValue;
    CXRefQualifier_RValue;
}

clang_Type_getNumTemplateArguments :: (T: CXType) -> s32 #foreign Clang;
clang_Type_getTemplateArgumentAsType :: (T: CXType, i: u32) -> CXType #foreign Clang;
clang_Type_getCXXRefQualifier :: (T: CXType) -> CXRefQualifierKind #foreign Clang;
clang_Cursor_isBitField :: (C: CXCursor) -> u32 #foreign Clang;
clang_isVirtualBase :: (C: CXCursor) -> u32 #foreign Clang;

using CX_CXXAccessSpecifier :: enum {
    CX_CXXInvalidAccessSpecifier;
    CX_CXXPublic;
    CX_CXXProtected;
    CX_CXXPrivate;
}

clang_getCXXAccessSpecifier :: (C: CXCursor) -> CX_CXXAccessSpecifier #foreign Clang;

using CX_StorageClass :: enum {
    CX_SC_Invalid;
    CX_SC_None;
    CX_SC_Extern;
    CX_SC_Static;
    CX_SC_PrivateExtern;
    CX_SC_OpenCLWorkGroupLocal;
    CX_SC_Auto;
    CX_SC_Register;
}

clang_Cursor_getStorageClass :: (C: CXCursor) -> CX_StorageClass #foreign Clang;
clang_getNumOverloadedDecls :: (cursor: CXCursor) -> u32 #foreign Clang;
clang_getOverloadedDecl :: (cursor: CXCursor, index: u32) -> CXCursor #foreign Clang;
clang_getIBOutletCollectionType :: (C: CXCursor) -> CXType #foreign Clang;

using CXChildVisitResult :: enum {
    CXChildVisit_Break;
    CXChildVisit_Continue;
    CXChildVisit_Recurse;
}

CXCursorVisitor :: #type (cursor: CXCursor, parent: CXCursor, client_data: CXClientData) -> CXChildVisitResult #c_call;


clang_visitChildren :: (parent: CXCursor, visitor: CXCursorVisitor, client_data: CXClientData) -> u32 #foreign Clang;
// #ifdef __has_feature
// #  if __has_feature(blocks)
// typedef enum CXChildVisitResult 
//      (^CXCursorVisitorBlock)(CXCursor cursor, CXCursor parent);
// CINDEX_LINKAGE unsigned clang_visitChildrenWithBlock(CXCursor parent,
//                                                     CXCursorVisitorBlock block);
// #  endif
// #endif
clang_getCursorUSR :: (C: CXCursor) -> CXString #foreign Clang;
clang_constructUSR_ObjCClass :: (class_name: *u8) -> CXString #foreign Clang;
clang_constructUSR_ObjCCategory :: (class_name: *u8, category_name: *u8) -> CXString #foreign Clang;
clang_constructUSR_ObjCProtocol :: (protocol_name: *u8) -> CXString #foreign Clang;
clang_constructUSR_ObjCIvar :: (name: *u8, classUSR: CXString) -> CXString #foreign Clang;
clang_constructUSR_ObjCMethod :: (name: *u8, isInstanceMethod: u32, classUSR: CXString) -> CXString #foreign Clang;
clang_constructUSR_ObjCProperty :: (property: *u8, classUSR: CXString) -> CXString #foreign Clang;
clang_getCursorSpelling :: (C: CXCursor) -> CXString #foreign Clang;
clang_Cursor_getSpellingNameRange :: (C: CXCursor, pieceIndex: u32, options: u32) -> CXSourceRange #foreign Clang;

/*
typedef void *CXPrintingPolicy;
enum CXPrintingPolicyProperty {
  CXPrintingPolicy_Indentation,
  CXPrintingPolicy_SuppressSpecifiers,
  CXPrintingPolicy_SuppressTagKeyword,
  CXPrintingPolicy_IncludeTagDefinition,
  CXPrintingPolicy_SuppressScope,
  CXPrintingPolicy_SuppressUnwrittenScope,
  CXPrintingPolicy_SuppressInitializers,
  CXPrintingPolicy_ConstantArraySizeAsWritten,
  CXPrintingPolicy_AnonymousTagLocations,
  CXPrintingPolicy_SuppressStrongLifetime,
  CXPrintingPolicy_SuppressLifetimeQualifiers,
  CXPrintingPolicy_SuppressTemplateArgsInCXXConstructors,
  CXPrintingPolicy_Bool,
  CXPrintingPolicy_Restrict,
  CXPrintingPolicy_Alignof,
  CXPrintingPolicy_UnderscoreAlignof,
  CXPrintingPolicy_UseVoidForZeroParams,
  CXPrintingPolicy_TerseOutput,
  CXPrintingPolicy_PolishForDeclaration,
  CXPrintingPolicy_Half,
  CXPrintingPolicy_MSWChar,
  CXPrintingPolicy_IncludeNewlines,
  CXPrintingPolicy_MSVCFormatting,
  CXPrintingPolicy_ConstantsAsWritten,
  CXPrintingPolicy_SuppressImplicitBase,
  CXPrintingPolicy_FullyQualifiedName,
  CXPrintingPolicy_LastProperty = CXPrintingPolicy_FullyQualifiedName
};
CINDEX_LINKAGE unsigned
clang_PrintingPolicy_getProperty(CXPrintingPolicy Policy,
                                 enum CXPrintingPolicyProperty Property);
CINDEX_LINKAGE void clang_PrintingPolicy_setProperty(CXPrintingPolicy Policy,
                                                     enum CXPrintingPolicyProperty Property,
                                                     unsigned Value);
CINDEX_LINKAGE CXPrintingPolicy clang_getCursorPrintingPolicy(CXCursor);
CINDEX_LINKAGE void clang_PrintingPolicy_dispose(CXPrintingPolicy Policy);
CINDEX_LINKAGE CXString clang_getCursorPrettyPrinted(CXCursor Cursor,
                                                     CXPrintingPolicy Policy);
CINDEX_LINKAGE CXString clang_getCursorDisplayName(CXCursor);
CINDEX_LINKAGE CXCursor clang_getCursorReferenced(CXCursor);
CINDEX_LINKAGE CXCursor clang_getCursorDefinition(CXCursor);
CINDEX_LINKAGE unsigned clang_isCursorDefinition(CXCursor);
CINDEX_LINKAGE CXCursor clang_getCanonicalCursor(CXCursor);
CINDEX_LINKAGE int clang_Cursor_getObjCSelectorIndex(CXCursor);
CINDEX_LINKAGE int clang_Cursor_isDynamicCall(CXCursor C);
CINDEX_LINKAGE CXType clang_Cursor_getReceiverType(CXCursor C);
typedef enum {
  CXObjCPropertyAttr_noattr    = 0x00,
  CXObjCPropertyAttr_readonly  = 0x01,
  CXObjCPropertyAttr_getter    = 0x02,
  CXObjCPropertyAttr_assign    = 0x04,
  CXObjCPropertyAttr_readwrite = 0x08,
  CXObjCPropertyAttr_retain    = 0x10,
  CXObjCPropertyAttr_copy      = 0x20,
  CXObjCPropertyAttr_nonatomic = 0x40,
  CXObjCPropertyAttr_setter    = 0x80,
  CXObjCPropertyAttr_atomic    = 0x100,
  CXObjCPropertyAttr_weak      = 0x200,
  CXObjCPropertyAttr_strong    = 0x400,
  CXObjCPropertyAttr_unsafe_unretained = 0x800,
  CXObjCPropertyAttr_class = 0x1000
} CXObjCPropertyAttrKind;
CINDEX_LINKAGE unsigned clang_Cursor_getObjCPropertyAttributes(CXCursor C,
                                                             unsigned reserved);
typedef enum {
  CXObjCDeclQualifier_None = 0x0,
  CXObjCDeclQualifier_In = 0x1,
  CXObjCDeclQualifier_Inout = 0x2,
  CXObjCDeclQualifier_Out = 0x4,
  CXObjCDeclQualifier_Bycopy = 0x8,
  CXObjCDeclQualifier_Byref = 0x10,
  CXObjCDeclQualifier_Oneway = 0x20
} CXObjCDeclQualifierKind;
CINDEX_LINKAGE unsigned clang_Cursor_getObjCDeclQualifiers(CXCursor C);
CINDEX_LINKAGE unsigned clang_Cursor_isObjCOptional(CXCursor C);
CINDEX_LINKAGE unsigned clang_Cursor_isVariadic(CXCursor C);
CINDEX_LINKAGE unsigned clang_Cursor_isExternalSymbol(CXCursor C,
                                       CXString *language, CXString *definedIn,
                                       unsigned *isGenerated);
CINDEX_LINKAGE CXSourceRange clang_Cursor_getCommentRange(CXCursor C);
CINDEX_LINKAGE CXString clang_Cursor_getRawCommentText(CXCursor C);
CINDEX_LINKAGE CXString clang_Cursor_getBriefCommentText(CXCursor C);
CINDEX_LINKAGE CXString clang_Cursor_getMangling(CXCursor);
CINDEX_LINKAGE CXStringSet *clang_Cursor_getCXXManglings(CXCursor);
CINDEX_LINKAGE CXStringSet *clang_Cursor_getObjCManglings(CXCursor);
typedef void *CXModule;
CINDEX_LINKAGE CXModule clang_Cursor_getModule(CXCursor C);
CINDEX_LINKAGE CXModule clang_getModuleForFile(CXTranslationUnit, CXFile);
CINDEX_LINKAGE CXFile clang_Module_getASTFile(CXModule Module);
CINDEX_LINKAGE CXModule clang_Module_getParent(CXModule Module);
CINDEX_LINKAGE CXString clang_Module_getName(CXModule Module);
CINDEX_LINKAGE CXString clang_Module_getFullName(CXModule Module);
CINDEX_LINKAGE int clang_Module_isSystem(CXModule Module);
CINDEX_LINKAGE unsigned clang_Module_getNumTopLevelHeaders(CXTranslationUnit,
                                                           CXModule Module);
CINDEX_LINKAGE
CXFile clang_Module_getTopLevelHeader(CXTranslationUnit,
                                      CXModule Module, unsigned Index);
CINDEX_LINKAGE unsigned clang_CXXConstructor_isConvertingConstructor(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXConstructor_isCopyConstructor(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXConstructor_isDefaultConstructor(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXConstructor_isMoveConstructor(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXField_isMutable(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXMethod_isDefaulted(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXMethod_isPureVirtual(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXMethod_isStatic(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXMethod_isVirtual(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXRecord_isAbstract(CXCursor C);
CINDEX_LINKAGE unsigned clang_EnumDecl_isScoped(CXCursor C);
CINDEX_LINKAGE unsigned clang_CXXMethod_isConst(CXCursor C);
CINDEX_LINKAGE enum CXCursorKind clang_getTemplateCursorKind(CXCursor C);
CINDEX_LINKAGE CXCursor clang_getSpecializedCursorTemplate(CXCursor C);
CINDEX_LINKAGE CXSourceRange clang_getCursorReferenceNameRange(CXCursor C,
                                                unsigned NameFlags, 
                                                unsigned PieceIndex);
enum CXNameRefFlags {
  CXNameRange_WantQualifier = 0x1,
  CXNameRange_WantTemplateArgs = 0x2,
  CXNameRange_WantSinglePiece = 0x4
};
typedef enum CXTokenKind {
  CXToken_Punctuation,
  CXToken_Keyword,
  CXToken_Identifier,
  CXToken_Literal,
  CXToken_Comment
} CXTokenKind;
typedef struct {
  unsigned int_data[4];
  void *ptr_data;
} CXToken;
CINDEX_LINKAGE CXToken *clang_getToken(CXTranslationUnit TU,
                                       CXSourceLocation Location);
CINDEX_LINKAGE CXTokenKind clang_getTokenKind(CXToken);
CINDEX_LINKAGE CXString clang_getTokenSpelling(CXTranslationUnit, CXToken);
CINDEX_LINKAGE CXSourceLocation clang_getTokenLocation(CXTranslationUnit,
                                                       CXToken);
CINDEX_LINKAGE CXSourceRange clang_getTokenExtent(CXTranslationUnit, CXToken);
CINDEX_LINKAGE void clang_tokenize(CXTranslationUnit TU, CXSourceRange Range,
                                   CXToken **Tokens, unsigned *NumTokens);
CINDEX_LINKAGE void clang_annotateTokens(CXTranslationUnit TU,
                                         CXToken *Tokens, unsigned NumTokens,
                                         CXCursor *Cursors);
CINDEX_LINKAGE void clang_disposeTokens(CXTranslationUnit TU,
                                        CXToken *Tokens, unsigned NumTokens);
CINDEX_LINKAGE CXString clang_getCursorKindSpelling(enum CXCursorKind Kind);
CINDEX_LINKAGE void clang_getDefinitionSpellingAndExtent(CXCursor,
                                          const char **startBuf,
                                          const char **endBuf,
                                          unsigned *startLine,
                                          unsigned *startColumn,
                                          unsigned *endLine,
                                          unsigned *endColumn);
CINDEX_LINKAGE void clang_enableStackTraces(void);
CINDEX_LINKAGE void clang_executeOnThread(void (*fn)(void*), void *user_data,
                                          unsigned stack_size);
typedef void *CXCompletionString;
typedef struct {
  enum CXCursorKind CursorKind;
  CXCompletionString CompletionString;
} CXCompletionResult;
enum CXCompletionChunkKind {
  CXCompletionChunk_Optional,
  CXCompletionChunk_TypedText,
  CXCompletionChunk_Text,
  CXCompletionChunk_Placeholder,
  CXCompletionChunk_Informative,
  CXCompletionChunk_CurrentParameter,
  CXCompletionChunk_LeftParen,
  CXCompletionChunk_RightParen,
  CXCompletionChunk_LeftBracket,
  CXCompletionChunk_RightBracket,
  CXCompletionChunk_LeftBrace,
  CXCompletionChunk_RightBrace,
  CXCompletionChunk_LeftAngle,
  CXCompletionChunk_RightAngle,
  CXCompletionChunk_Comma,
  CXCompletionChunk_ResultType,
  CXCompletionChunk_Colon,
  CXCompletionChunk_SemiColon,
  CXCompletionChunk_Equal,
  CXCompletionChunk_HorizontalSpace,
  CXCompletionChunk_VerticalSpace
};
CINDEX_LINKAGE enum CXCompletionChunkKind
clang_getCompletionChunkKind(CXCompletionString completion_string,
                             unsigned chunk_number);
CINDEX_LINKAGE CXString
clang_getCompletionChunkText(CXCompletionString completion_string,
                             unsigned chunk_number);
CINDEX_LINKAGE CXCompletionString
clang_getCompletionChunkCompletionString(CXCompletionString completion_string,
                                         unsigned chunk_number);
CINDEX_LINKAGE unsigned
clang_getNumCompletionChunks(CXCompletionString completion_string);
CINDEX_LINKAGE unsigned
clang_getCompletionPriority(CXCompletionString completion_string);
CINDEX_LINKAGE enum CXAvailabilityKind 
clang_getCompletionAvailability(CXCompletionString completion_string);
CINDEX_LINKAGE unsigned
clang_getCompletionNumAnnotations(CXCompletionString completion_string);
CINDEX_LINKAGE CXString
clang_getCompletionAnnotation(CXCompletionString completion_string,
                              unsigned annotation_number);
CINDEX_LINKAGE CXString
clang_getCompletionParent(CXCompletionString completion_string,
                          enum CXCursorKind *kind);
CINDEX_LINKAGE CXString
clang_getCompletionBriefComment(CXCompletionString completion_string);
CINDEX_LINKAGE CXCompletionString
clang_getCursorCompletionString(CXCursor cursor);
typedef struct {
  CXCompletionResult *Results;
  unsigned NumResults;
} CXCodeCompleteResults;
CINDEX_LINKAGE unsigned
clang_getCompletionNumFixIts(CXCodeCompleteResults *results,
                             unsigned completion_index);
CINDEX_LINKAGE CXString clang_getCompletionFixIt(
    CXCodeCompleteResults *results, unsigned completion_index,
    unsigned fixit_index, CXSourceRange *replacement_range);
enum CXCodeComplete_Flags {
  CXCodeComplete_IncludeMacros = 0x01,
  CXCodeComplete_IncludeCodePatterns = 0x02,
  CXCodeComplete_IncludeBriefComments = 0x04,
  CXCodeComplete_SkipPreamble = 0x08,
  CXCodeComplete_IncludeCompletionsWithFixIts = 0x10
};
enum CXCompletionContext {
  CXCompletionContext_Unexposed = 0,
  CXCompletionContext_AnyType = 1 << 0,
  CXCompletionContext_AnyValue = 1 << 1,
  CXCompletionContext_ObjCObjectValue = 1 << 2,
  CXCompletionContext_ObjCSelectorValue = 1 << 3,
  CXCompletionContext_CXXClassTypeValue = 1 << 4,
  CXCompletionContext_DotMemberAccess = 1 << 5,
  CXCompletionContext_ArrowMemberAccess = 1 << 6,
  CXCompletionContext_ObjCPropertyAccess = 1 << 7,
  CXCompletionContext_EnumTag = 1 << 8,
  CXCompletionContext_UnionTag = 1 << 9,
  CXCompletionContext_StructTag = 1 << 10,
  CXCompletionContext_ClassTag = 1 << 11,
  CXCompletionContext_Namespace = 1 << 12,
  CXCompletionContext_NestedNameSpecifier = 1 << 13,
  CXCompletionContext_ObjCInterface = 1 << 14,
  CXCompletionContext_ObjCProtocol = 1 << 15,
  CXCompletionContext_ObjCCategory = 1 << 16,
  CXCompletionContext_ObjCInstanceMessage = 1 << 17,
  CXCompletionContext_ObjCClassMessage = 1 << 18,
  CXCompletionContext_ObjCSelectorName = 1 << 19,
  CXCompletionContext_MacroName = 1 << 20,
  CXCompletionContext_NaturalLanguage = 1 << 21,
  CXCompletionContext_Unknown = ((1 << 22) - 1)
};
CINDEX_LINKAGE unsigned clang_defaultCodeCompleteOptions(void);
CINDEX_LINKAGE
CXCodeCompleteResults *clang_codeCompleteAt(CXTranslationUnit TU,
                                            const char *complete_filename,
                                            unsigned complete_line,
                                            unsigned complete_column,
                                            struct CXUnsavedFile *unsaved_files,
                                            unsigned num_unsaved_files,
                                            unsigned options);
CINDEX_LINKAGE
void clang_sortCodeCompletionResults(CXCompletionResult *Results,
                                     unsigned NumResults);
CINDEX_LINKAGE
void clang_disposeCodeCompleteResults(CXCodeCompleteResults *Results);
CINDEX_LINKAGE
unsigned clang_codeCompleteGetNumDiagnostics(CXCodeCompleteResults *Results);
CINDEX_LINKAGE
CXDiagnostic clang_codeCompleteGetDiagnostic(CXCodeCompleteResults *Results,
                                             unsigned Index);
CINDEX_LINKAGE
unsigned long long clang_codeCompleteGetContexts(
                                                CXCodeCompleteResults *Results);
CINDEX_LINKAGE
enum CXCursorKind clang_codeCompleteGetContainerKind(
                                                 CXCodeCompleteResults *Results,
                                                     unsigned *IsIncomplete);
CINDEX_LINKAGE
CXString clang_codeCompleteGetContainerUSR(CXCodeCompleteResults *Results);
CINDEX_LINKAGE
CXString clang_codeCompleteGetObjCSelector(CXCodeCompleteResults *Results);
CINDEX_LINKAGE CXString clang_getClangVersion(void);
CINDEX_LINKAGE void clang_toggleCrashRecovery(unsigned isEnabled);
typedef void (*CXInclusionVisitor)(CXFile included_file,
                                   CXSourceLocation* inclusion_stack,
                                   unsigned include_len,
                                   CXClientData client_data);
CINDEX_LINKAGE void clang_getInclusions(CXTranslationUnit tu,
                                        CXInclusionVisitor visitor,
                                        CXClientData client_data);
typedef enum {
  CXEval_Int = 1 ,
  CXEval_Float = 2,
  CXEval_ObjCStrLiteral = 3,
  CXEval_StrLiteral = 4,
  CXEval_CFStr = 5,
  CXEval_Other = 6,
  CXEval_UnExposed = 0
} CXEvalResultKind ;
typedef void * CXEvalResult;
CINDEX_LINKAGE CXEvalResult clang_Cursor_Evaluate(CXCursor C);
CINDEX_LINKAGE CXEvalResultKind clang_EvalResult_getKind(CXEvalResult E);
CINDEX_LINKAGE int clang_EvalResult_getAsInt(CXEvalResult E);
CINDEX_LINKAGE long long clang_EvalResult_getAsLongLong(CXEvalResult E);
CINDEX_LINKAGE unsigned clang_EvalResult_isUnsignedInt(CXEvalResult E);
CINDEX_LINKAGE unsigned long long clang_EvalResult_getAsUnsigned(CXEvalResult E);
CINDEX_LINKAGE double clang_EvalResult_getAsDouble(CXEvalResult E);
CINDEX_LINKAGE const char* clang_EvalResult_getAsStr(CXEvalResult E);
CINDEX_LINKAGE void clang_EvalResult_dispose(CXEvalResult E);
typedef void *CXRemapping;
CINDEX_LINKAGE CXRemapping clang_getRemappings(const char *path);
CINDEX_LINKAGE
CXRemapping clang_getRemappingsFromFileList(const char **filePaths,
                                            unsigned numFiles);
CINDEX_LINKAGE unsigned clang_remap_getNumFiles(CXRemapping);
CINDEX_LINKAGE void clang_remap_getFilenames(CXRemapping, unsigned index,
                                     CXString *original, CXString *transformed);
CINDEX_LINKAGE void clang_remap_dispose(CXRemapping);
enum CXVisitorResult {
  CXVisit_Break,
  CXVisit_Continue
};
typedef struct CXCursorAndRangeVisitor {
  void *context;
  enum CXVisitorResult (*visit)(void *context, CXCursor, CXSourceRange);
} CXCursorAndRangeVisitor;
typedef enum {
  CXResult_Success = 0,
  CXResult_Invalid = 1,
  CXResult_VisitBreak = 2
} CXResult;
CINDEX_LINKAGE CXResult clang_findReferencesInFile(CXCursor cursor, CXFile file,
                                               CXCursorAndRangeVisitor visitor);
CINDEX_LINKAGE CXResult clang_findIncludesInFile(CXTranslationUnit TU,
                                                 CXFile file,
                                              CXCursorAndRangeVisitor visitor);
#ifdef __has_feature
#  if __has_feature(blocks)
typedef enum CXVisitorResult
    (^CXCursorAndRangeVisitorBlock)(CXCursor, CXSourceRange);
CINDEX_LINKAGE
CXResult clang_findReferencesInFileWithBlock(CXCursor, CXFile,
                                             CXCursorAndRangeVisitorBlock);
CINDEX_LINKAGE
CXResult clang_findIncludesInFileWithBlock(CXTranslationUnit, CXFile,
                                           CXCursorAndRangeVisitorBlock);
#  endif
#endif
typedef void *CXIdxClientFile;
typedef void *CXIdxClientEntity;
typedef void *CXIdxClientContainer;
typedef void *CXIdxClientASTFile;
typedef struct {
  void *ptr_data[2];
  unsigned int_data;
} CXIdxLoc;
typedef struct {
  CXIdxLoc hashLoc;
  const char *filename;
  CXFile file;
  int isImport;
  int isAngled;
  int isModuleImport;
} CXIdxIncludedFileInfo;
typedef struct {
  CXFile file;
  CXModule module;
  CXIdxLoc loc;
  int isImplicit;
} CXIdxImportedASTFileInfo;
typedef enum {
  CXIdxEntity_Unexposed     = 0,
  CXIdxEntity_Typedef       = 1,
  CXIdxEntity_Function      = 2,
  CXIdxEntity_Variable      = 3,
  CXIdxEntity_Field         = 4,
  CXIdxEntity_EnumConstant  = 5,
  CXIdxEntity_ObjCClass     = 6,
  CXIdxEntity_ObjCProtocol  = 7,
  CXIdxEntity_ObjCCategory  = 8,
  CXIdxEntity_ObjCInstanceMethod = 9,
  CXIdxEntity_ObjCClassMethod    = 10,
  CXIdxEntity_ObjCProperty  = 11,
  CXIdxEntity_ObjCIvar      = 12,
  CXIdxEntity_Enum          = 13,
  CXIdxEntity_Struct        = 14,
  CXIdxEntity_Union         = 15,
  CXIdxEntity_CXXClass              = 16,
  CXIdxEntity_CXXNamespace          = 17,
  CXIdxEntity_CXXNamespaceAlias     = 18,
  CXIdxEntity_CXXStaticVariable     = 19,
  CXIdxEntity_CXXStaticMethod       = 20,
  CXIdxEntity_CXXInstanceMethod     = 21,
  CXIdxEntity_CXXConstructor        = 22,
  CXIdxEntity_CXXDestructor         = 23,
  CXIdxEntity_CXXConversionFunction = 24,
  CXIdxEntity_CXXTypeAlias          = 25,
  CXIdxEntity_CXXInterface          = 26
} CXIdxEntityKind;
typedef enum {
  CXIdxEntityLang_None = 0,
  CXIdxEntityLang_C    = 1,
  CXIdxEntityLang_ObjC = 2,
  CXIdxEntityLang_CXX  = 3,
  CXIdxEntityLang_Swift  = 4
} CXIdxEntityLanguage;
typedef enum {
  CXIdxEntity_NonTemplate   = 0,
  CXIdxEntity_Template      = 1,
  CXIdxEntity_TemplatePartialSpecialization = 2,
  CXIdxEntity_TemplateSpecialization = 3
} CXIdxEntityCXXTemplateKind;
typedef enum {
  CXIdxAttr_Unexposed     = 0,
  CXIdxAttr_IBAction      = 1,
  CXIdxAttr_IBOutlet      = 2,
  CXIdxAttr_IBOutletCollection = 3
} CXIdxAttrKind;
typedef struct {
  CXIdxAttrKind kind;
  CXCursor cursor;
  CXIdxLoc loc;
} CXIdxAttrInfo;
typedef struct {
  CXIdxEntityKind kind;
  CXIdxEntityCXXTemplateKind templateKind;
  CXIdxEntityLanguage lang;
  const char *name;
  const char *USR;
  CXCursor cursor;
  const CXIdxAttrInfo *const *attributes;
  unsigned numAttributes;
} CXIdxEntityInfo;
typedef struct {
  CXCursor cursor;
} CXIdxContainerInfo;
typedef struct {
  const CXIdxAttrInfo *attrInfo;
  const CXIdxEntityInfo *objcClass;
  CXCursor classCursor;
  CXIdxLoc classLoc;
} CXIdxIBOutletCollectionAttrInfo;
typedef enum {
  CXIdxDeclFlag_Skipped = 0x1
} CXIdxDeclInfoFlags;
typedef struct {
  const CXIdxEntityInfo *entityInfo;
  CXCursor cursor;
  CXIdxLoc loc;
  const CXIdxContainerInfo *semanticContainer;
  const CXIdxContainerInfo *lexicalContainer;
  int isRedeclaration;
  int isDefinition;
  int isContainer;
  const CXIdxContainerInfo *declAsContainer;
  int isImplicit;
  const CXIdxAttrInfo *const *attributes;
  unsigned numAttributes;
  unsigned flags;
} CXIdxDeclInfo;
typedef enum {
  CXIdxObjCContainer_ForwardRef = 0,
  CXIdxObjCContainer_Interface = 1,
  CXIdxObjCContainer_Implementation = 2
} CXIdxObjCContainerKind;
typedef struct {
  const CXIdxDeclInfo *declInfo;
  CXIdxObjCContainerKind kind;
} CXIdxObjCContainerDeclInfo;
typedef struct {
  const CXIdxEntityInfo *base;
  CXCursor cursor;
  CXIdxLoc loc;
} CXIdxBaseClassInfo;
typedef struct {
  const CXIdxEntityInfo *protocol;
  CXCursor cursor;
  CXIdxLoc loc;
} CXIdxObjCProtocolRefInfo;
typedef struct {
  const CXIdxObjCProtocolRefInfo *const *protocols;
  unsigned numProtocols;
} CXIdxObjCProtocolRefListInfo;
typedef struct {
  const CXIdxObjCContainerDeclInfo *containerInfo;
  const CXIdxBaseClassInfo *superInfo;
  const CXIdxObjCProtocolRefListInfo *protocols;
} CXIdxObjCInterfaceDeclInfo;
typedef struct {
  const CXIdxObjCContainerDeclInfo *containerInfo;
  const CXIdxEntityInfo *objcClass;
  CXCursor classCursor;
  CXIdxLoc classLoc;
  const CXIdxObjCProtocolRefListInfo *protocols;
} CXIdxObjCCategoryDeclInfo;
typedef struct {
  const CXIdxDeclInfo *declInfo;
  const CXIdxEntityInfo *getter;
  const CXIdxEntityInfo *setter;
} CXIdxObjCPropertyDeclInfo;
typedef struct {
  const CXIdxDeclInfo *declInfo;
  const CXIdxBaseClassInfo *const *bases;
  unsigned numBases;
} CXIdxCXXClassDeclInfo;
typedef enum {
  CXIdxEntityRef_Direct = 1,
  CXIdxEntityRef_Implicit = 2
} CXIdxEntityRefKind;
typedef enum {
  CXSymbolRole_None = 0,
  CXSymbolRole_Declaration = 1 << 0,
  CXSymbolRole_Definition = 1 << 1,
  CXSymbolRole_Reference = 1 << 2,
  CXSymbolRole_Read = 1 << 3,
  CXSymbolRole_Write = 1 << 4,
  CXSymbolRole_Call = 1 << 5,
  CXSymbolRole_Dynamic = 1 << 6,
  CXSymbolRole_AddressOf = 1 << 7,
  CXSymbolRole_Implicit = 1 << 8
} CXSymbolRole;
typedef struct {
  CXIdxEntityRefKind kind;
  CXCursor cursor;
  CXIdxLoc loc;
  const CXIdxEntityInfo *referencedEntity;
  const CXIdxEntityInfo *parentEntity;
  const CXIdxContainerInfo *container;
  CXSymbolRole role;
} CXIdxEntityRefInfo;
typedef struct {
  int (*abortQuery)(CXClientData client_data, void *reserved);
  void (*diagnostic)(CXClientData client_data,
                     CXDiagnosticSet, void *reserved);
  CXIdxClientFile (*enteredMainFile)(CXClientData client_data,
                                     CXFile mainFile, void *reserved);
  CXIdxClientFile (*ppIncludedFile)(CXClientData client_data,
                                    const CXIdxIncludedFileInfo *);
  CXIdxClientASTFile (*importedASTFile)(CXClientData client_data,
                                        const CXIdxImportedASTFileInfo *);
  CXIdxClientContainer (*startedTranslationUnit)(CXClientData client_data,
                                                 void *reserved);
  void (*indexDeclaration)(CXClientData client_data,
                           const CXIdxDeclInfo *);
  void (*indexEntityReference)(CXClientData client_data,
                               const CXIdxEntityRefInfo *);
} IndexerCallbacks;
CINDEX_LINKAGE int clang_index_isEntityObjCContainerKind(CXIdxEntityKind);
CINDEX_LINKAGE const CXIdxObjCContainerDeclInfo *
clang_index_getObjCContainerDeclInfo(const CXIdxDeclInfo *);
CINDEX_LINKAGE const CXIdxObjCInterfaceDeclInfo *
clang_index_getObjCInterfaceDeclInfo(const CXIdxDeclInfo *);
CINDEX_LINKAGE
const CXIdxObjCCategoryDeclInfo *
clang_index_getObjCCategoryDeclInfo(const CXIdxDeclInfo *);
CINDEX_LINKAGE const CXIdxObjCProtocolRefListInfo *
clang_index_getObjCProtocolRefListInfo(const CXIdxDeclInfo *);
CINDEX_LINKAGE const CXIdxObjCPropertyDeclInfo *
clang_index_getObjCPropertyDeclInfo(const CXIdxDeclInfo *);
CINDEX_LINKAGE const CXIdxIBOutletCollectionAttrInfo *
clang_index_getIBOutletCollectionAttrInfo(const CXIdxAttrInfo *);
CINDEX_LINKAGE const CXIdxCXXClassDeclInfo *
clang_index_getCXXClassDeclInfo(const CXIdxDeclInfo *);
CINDEX_LINKAGE CXIdxClientContainer
clang_index_getClientContainer(const CXIdxContainerInfo *);
CINDEX_LINKAGE void
clang_index_setClientContainer(const CXIdxContainerInfo *,CXIdxClientContainer);
CINDEX_LINKAGE CXIdxClientEntity
clang_index_getClientEntity(const CXIdxEntityInfo *);
CINDEX_LINKAGE void
clang_index_setClientEntity(const CXIdxEntityInfo *, CXIdxClientEntity);
typedef void *CXIndexAction;
CINDEX_LINKAGE CXIndexAction clang_IndexAction_create(CXIndex CIdx);
CINDEX_LINKAGE void clang_IndexAction_dispose(CXIndexAction);
typedef enum {
  CXIndexOpt_None = 0x0,
  CXIndexOpt_SuppressRedundantRefs = 0x1,
  CXIndexOpt_IndexFunctionLocalSymbols = 0x2,
  CXIndexOpt_IndexImplicitTemplateInstantiations = 0x4,
  CXIndexOpt_SuppressWarnings = 0x8,
  CXIndexOpt_SkipParsedBodiesInSession = 0x10
} CXIndexOptFlags;
CINDEX_LINKAGE int clang_indexSourceFile(CXIndexAction,
                                         CXClientData client_data,
                                         IndexerCallbacks *index_callbacks,
                                         unsigned index_callbacks_size,
                                         unsigned index_options,
                                         const char *source_filename,
                                         const char * const *command_line_args,
                                         int num_command_line_args,
                                         struct CXUnsavedFile *unsaved_files,
                                         unsigned num_unsaved_files,
                                         CXTranslationUnit *out_TU,
                                         unsigned TU_options);
CINDEX_LINKAGE int clang_indexSourceFileFullArgv(
    CXIndexAction, CXClientData client_data, IndexerCallbacks *index_callbacks,
    unsigned index_callbacks_size, unsigned index_options,
    const char *source_filename, const char *const *command_line_args,
    int num_command_line_args, struct CXUnsavedFile *unsaved_files,
    unsigned num_unsaved_files, CXTranslationUnit *out_TU, unsigned TU_options);
CINDEX_LINKAGE int clang_indexTranslationUnit(CXIndexAction,
                                              CXClientData client_data,
                                              IndexerCallbacks *index_callbacks,
                                              unsigned index_callbacks_size,
                                              unsigned index_options,
                                              CXTranslationUnit);
CINDEX_LINKAGE void clang_indexLoc_getFileLocation(CXIdxLoc loc,
                                                   CXIdxClientFile *indexFile,
                                                   CXFile *file,
                                                   unsigned *line,
                                                   unsigned *column,
                                                   unsigned *offset);
CINDEX_LINKAGE
CXSourceLocation clang_indexLoc_getCXSourceLocation(CXIdxLoc loc);
typedef enum CXVisitorResult (*CXFieldVisitor)(CXCursor C,
                                               CXClientData client_data);
CINDEX_LINKAGE unsigned clang_Type_visitFields(CXType T,
                                               CXFieldVisitor visitor,
                                               CXClientData client_data);
#endif
*/
