clear
close all
clc

subjects = [1] ;

ConditionNameArray = {'free', 'simple', 'gonogo'} ;
nCondition = length(ConditionNameArray) ;

for iSubject = subjects
    
    dataFilePath = sprintf('x3_DataChecked/Data%02d', iSubject) ;
    load(dataFilePath)
    
    for iCondition = 1:nCondition

        nTrial = size(DataArray, 1) ;
        
        for iTrial = 1:nTrial
            
            Data = DataArray(iTrial, iCondition) ;
            
            Result = m3_analyze_single_trial(Data) ;
            
            SingleTrialResultArray(iTrial, iCondition) = Result ;
            clear Result
            
        end
        
        
    end
    
    resultFilePath = sprintf('x4_SingleTrialAnalysisResults/SingleTrialAnalysisResults%02d', iSubject) ;
    save(resultFilePath, 'SingleTrialResultArray') ;
    
    
end


