%set up matrix with raw EMG data
total_time= 5000;
raw_EMG_Matrix = zeros(3, total_time);

c = 0;
n = 1;
user_counter = 0;
d = 0;
disp('Begin: Rest')
while n < total_time + 1
    
    

    %query for position
    flushinput(bt);
    flushoutput(bt);
    [pos_current, count, msg] = query(bt, '$b/n');
    pos_current = str2num(pos_current((6):end-1));
    flushinput(bt);
    flushoutput(bt);
    
    %pause(.1)
    
%     flushoutput(bt);
%     flushinput(bt);
    [EMG_out, count, msg] = query(bt, '$x/n');
    flushinput(bt);
    flushoutput(bt);
    
    %pause(.008)
    
    if length(EMG_out) > 2
    if EMG_out(2) == 'x'
    if length(pos_current) == 1   
        %query for raw EMG
%         flushinput(bt);
%         flushoutput(bt);
        EMG1 = str2num(EMG_out((6):8));
        EMG2 = str2num(EMG_out((10):length(EMG_out)-1));
        
        %put values into the matrix
        raw_EMG_Matrix(1,n) = EMG1;
        raw_EMG_Matrix(2,n) = EMG2;
        
        raw_EMG_Matrix(3,n) = pos_current;
        
        flushinput(bt);
        flushoutput(bt);
        
        n = n + 1;
        user_counter = user_counter + 1;
    
    end
    end
    end
    if user_counter == 80 && d == 0
        
        disp('Get Ready: Up')
        pause(.1)
        d = 1;
    elseif user_counter == 80 && d == 1
        
        disp('Get Ready: Down')
        pause(.1)
        d = 2;
    elseif user_counter == 80 && d == 2
        
        disp('Get Ready: Rest')
        pause(.1)
        d = 0;
    end
    if user_counter == 100
        user_counter = 0;
        disp('Go')
        pause(.25)
    end
%     flushinput(bt);
%     flushoutput(bt);
    %pause(.01)
%     flushinput(bt);
%     flushoutput(bt);
end

disp(n)


%% Post Processing 
%windowing value
window = 10;

%set up matrices for averaging 
Trainable_Matrix = zeros(total_time/window, 8); 
temp_EMG1 = zeros(1, window);
temp_EMG2 = zeros(1, window);
temp_label = zeros(1, window);
counter = 0;

%set up matrices 
for n = 1:total_time
    disp(n)
    counter = counter + 1;
    temp_EMG1(1, counter) = raw_EMG_Matrix(1, n);
    temp_EMG2(1, counter) = raw_EMG_Matrix(2, n);
    temp_label(1, counter) = raw_EMG_Matrix(3, n);
    
    if counter == window
        
        Trainable_Matrix(n/window, 1) = mean(temp_EMG1);
        Trainable_Matrix(n/window, 2) = mean(temp_EMG2);
        Trainable_Matrix(n/window, 3) = median(temp_EMG1);
        Trainable_Matrix(n/window, 4) = median(temp_EMG2);
        Trainable_Matrix(n/window, 5) = var(temp_EMG1);
        Trainable_Matrix(n/window, 6) = var(temp_EMG2);
        
        %position bin labels low, middle, top
        %not used during original experiment 
        if mean(temp_label) <= 33.3
            Trainable_Matrix(n/window, 7) = 7;
        elseif mean(temp_label) > 33.3 && mean(temp_label) < 66.6
            Trainable_Matrix(n/window, 7) = 8;
        elseif mean(temp_label) >= 66.6
             Trainable_Matrix(n/window, 7) = 9;
        end
            
%set labels
        %uses two to set a window of movement range, counted as a deadband.
        %therefore movement within two degees is counted as the device may
        %move a little even when still
        
        if temp_label(1,10) - 2 < temp_label(1,1) && temp_label(1,1) < temp_label(1,10) + 2 
            Trainable_Matrix(n/window, 8) = 0;
        elseif temp_label(1,10)>temp_label(1,1) 
            Trainable_Matrix(n/window, 8) = 1;
        elseif temp_label(1,10)<temp_label(1,1) 
            Trainable_Matrix(n/window, 8) = 2;
        end
        
        counter = 0;
    end
end

%clean up any missed labels caused by the sampling of the angle faster than
%the user can change directions
for x = 2:total_time/window

        if Trainable_Matrix(x, 8) == 0 
            if Trainable_Matrix(x-1, 8) == 1 && Trainable_Matrix(x+1, 8) == 2
                Trainable_Matrix(x, 8) = 2;
            elseif Trainable_Matrix(x-1, 8) == 2 && Trainable_Matrix(x+1, 8) == 1
                Trainable_Matrix(x, 8) = 1;
            end
        end
end
     
%% Predicting signals and export commands
%need to set intitial position, and make sure position can not leave range

%set before use
limit_lower = 0
limit_upper = 70
trial_time = 8000;

%SET TO 30 FOR ALL TRIALS, EXCEPT ANGLE MATCH SET TO 0
fwrite(bt, sprintf('$C %f 30\n', 30));
% trial matrix
TrialMatrix_block5_UA_Hugh = zeros(3, trial_time);

%temp = Net_Trainable_Matrix(1:400, 1:6)
%temp(1:400, 7) = Net_Trainable_Matrix(1:400, 9)
%flush the output ans establish and initial position
[trainedClassifier, validationAccuracy] = trainClassifier_SVML(Trainable_Matrix)
pause(2);
flushinput(bt);
flushoutput(bt);
[out, count, msg] = query(bt, '$b/n');

%matriceses used for windowing the EMG data
raw_EMG1 = zeros(1,5);
raw_EMG2 = zeros(1,5);
raw_pos = zeros(1,5);
flushinput(bt);
flushoutput(bt);
pos = str2num(out((6):end-1));

%data sent to the KNN
input_data = zeros(1,7);

counter = 1;

for n = 1:trial_time
    
    
    
    % flush the input to matlab and obtain EMG signals 
    %'$x/n' is command for get EMG vals
    %disp('start')
    
    flushoutput(bt);
    flushinput(bt);
    
    
    [EMG_out, count, msg] = query(bt, '$x/n');
    
    
    flushinput(bt);
    flushoutput(bt);
    
    [out, count, msg] = query(bt, '$b/n');
    pos = str2num(out((6):end-1)); 
    posr = pos;
    if length(posr) < 1
        
        posr = 0;
    end
   
    
    flushinput(bt);
    flushoutput(bt);
        
    %make sure we have recieved a usable output from the device
    
    if length(EMG_out) > 2
    if EMG_out(2) == 'x'
        EMG1 = str2num(EMG_out((6):8));
        EMG2 = str2num(EMG_out((10):length(EMG_out)-1));
        

        rawEMG1(1, counter) = EMG1;
        rawEMG2(1, counter) = EMG2;
        
        raw_pos(1, counter) = posr;
        
        
        
        
        

        
        %input EMG info into classifier 
        %if trainedClassifier.predictFcn(EMG1, EMG2) == 1
        
        if counter == 5
        input_data(1,1) = mean(rawEMG1);
        input_data(1,2) = mean(rawEMG2);
        input_data(1,3) = median(rawEMG1);
        input_data(1,4) = median(rawEMG2);
        input_data(1,5) = var(rawEMG1);
        input_data(1,6) = var(rawEMG2);
        
        if mean(raw_pos) <= 33.3
            input_data(1,7) = 7;
        elseif mean(raw_pos) > 33.3 && mean(raw_pos) < 66.6
            input_data(1,7) = 8;
        elseif mean(raw_pos) >= 66.6
             input_data(1,7) = 9;
        end
        
        
        %COLLECT DATA
%         TrialMatrix_block5_UA_Hugh = input_data(1,1);
%         TrialMatrix_block5_UA_Hugh = input_data(1,2);
%         
%         WA_1 = 0;
%         WA_2 = 0;
%         for x = 1:10
%             if temp_EMG1(1, x) > mean(rawEMG1)
%                 WA_1 = WA_1 + 1;
%             end
%             if temp_EMG2(1, x) > mean(rawEMG2)
%                 WA_2 = WA_2 + 1;
%             end
%         end
% 
%         input_data(1, 7) = WA_1;
%         input_data(2, 8) = WA_2;
            

        
        
        [pot_label, score] = trainedClassifier.predictFcn(input_data)
        flushinput(bt);
        flushoutput(bt);
    
        [out, count, msg] = query(bt, '$b/n');
        pos = str2num(out((6):end-1)); 
        flushinput(bt);
        flushoutput(bt);
        
        %disp(score(1,3))
        %debugging pause
        %pause(.5)
        %Notes: If uses simple majority, should it be over 50% certainty?
        
%         if score(1,3) > .7
%                 pot_label = 2;
%                 disp(pot_label)
%          end
%         if pos > 50
%             if score(1,3) > .38
%                 pot_label = 2;
%                 
%             end
%         end
        
        if  pot_label == 1
            %parameter to adjust to improve use
            if pos < limit_upper
            if pos < 50
                pos = pos - 2;
            else
                pos = pos - 2;
            end

            %clip value to correct range
%             if pos < 0
%                 pos = 0; 
%             end

            %check for out of bounds of comfort
            
                %pos = 65;
            
            flushoutput(bt)
            flushinput(bt);
%             TrialMatrix_Num_Type_Name(3,n) = pos;
             [pos_dispose, count, msg] = query(bt, sprintf('$C %f 50\n', pos));
            end
            
            flushinput(bt);
            flushoutput(bt)
            %check this value
            

            %position check
            
            

        %2 is down
        %elseif trainedClassifier.predictFcn(EMG1, EMG2) == 2
        elseif  pot_label == 2
            if pos > limit_lower
            if pos > 30
                pos = pos - 10;
            else
                pos = pos - 10;
            end
            

            %clipping
            
                %pos = 5; 
            
            
            flushoutput(bt);
            flushinput(bt);
            %TrialMatrix_Num_Type_Name(3,n) = pos;
             [pos_dispose, count, msg] = query(bt, sprintf('$C %f 50\n', pos));
            
            end
            flushinput(bt);
            flushoutput(bt);
            %check this value
            

            %position check
            
            

        elseif pot_label == 0
%             TrialMatrix_block5_UA_Hugh(3,n) = pos;
        

        %3rd state == 0 is stationary 
        end
        counter = 0;
        end
        
        %increment counter after successfully adding a value to the matrix
        counter = counter + 1;
    end
    end
%         %position check
%         flushinput(bt);
%         [pos_out, count, msg] = query(bt, '$b/n');
%         flushinput(bt);
%         actual_pos = str2num(pos_out((6):end-1)); 
% 
%         if actual_pos ~= pos
%             pos = actual_pos;
%         end
    pause(.01) %may want to adjust value
    
end

disp('done')
