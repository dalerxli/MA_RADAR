
% Extension class of the original signal class to allow for multiple
% targets
classdef signal2 < handle
    properties 
        % transmit array class
        tx 
        % receive array class
        rx
        % target
        target
        numberofTargets
        % delay time for each target,transmitter and receiver
        deltaT 
    end

    methods
        % constructor function
        function obj = signal2(txarray,rxarray,varargin)
            txn = txarray.numberofElements; 
            rxn = rxarray.numberofElements; 
            targetn = size(varargin,2); 
            obj.numberofTargets = targetn; 
            
            obj.tx = txarray; 
            obj.rx = rxarray; 
            for i = 1:targetn
                 target_array(i) = varargin{i}; 
            end
            obj.target = target_array;
            
            obj.deltaT = zeros(txn,rxn,targetn); 
            
            for txi = 1:txn
                for rxj = 1:rxn
                    for k = 1:targetn
                        deltaX = obj.target(k).x-obj.rx.xE(rxj)+...
                            obj.target(k).x - obj.tx.xE(txi);
                        deltaY = obj.target(k).y-obj.rx.yE(rxj)+...
                            obj.target(k).y - obj.tx.yE(txi);
                        deltaZ = obj.target(k).z-obj.rx.zE(rxj)+...
                            obj.target(k).z - obj.tx.zE(txi);
                        delta = [deltaX,deltaY,deltaZ];
                        obj.deltaT(txi,rxj,k) = norm(delta)/(obj.tx.c);
                    end
                end
            end
        end

        % In case of moving targets 
        function deltaT2 = deltaT2(obj,txi,rxj,k)
            deltaX = obj.target(k).x-obj.rx.xE(rxj)+...
                obj.target(k).x - obj.tx.xE(txi);
            deltaY = obj.target(k).y-obj.rx.yE(rxj)+...
                obj.target(k).y - obj.tx.yE(txi);
            deltaZ = obj.target(k).z-obj.rx.zE(rxj)+...
                obj.target(k).z - obj.tx.zE(txi);
            delta = [deltaX,deltaY,deltaZ];
            deltaT2 = norm(delta)/(obj.tx.c);
        end
        
        % General next time function
        function nextTimeStep(obj)
            obj.tx.nextStep_sampling(); 
            targetn = size(obj.target,2);
            for targeti = 1:targetn
               obj.target(targeti).move(obj.tx.samplingRate);  
            end
        end

        % calculates the received signal after mixing it with a local
        % copy of the singal  for a single target
        function s = receivedSignal(obj,t,txi,rxi,targeti)
            t1 = 2*pi*obj.tx.k*obj.deltaT(txi,rxi,targeti)*t;
            t2 = -pi*obj.tx.k*(obj.deltaT(txi,rxi,targeti)^2);
            t3 = 2*pi*obj.tx.frequency*obj.deltaT(txi,rxi,targeti);
            s = exp(1i*(t1+t2+t3)); 
        end
        %Calculates the frequency of the received signal considering all
        %delays 
        function s = rxSignal(obj,time,txi,rxi,targeti)
            delay = obj.deltaT(txi,rxi,targeti);  
            time = time-delay; 
            s = obj.tx.txSignal(txi,time);
        end
        % Function to calculate the complete received signal for a static
        % scatterer 
        function s = rxSignal2(obj,time,txi,rxi,targeti)
            delay = obj.deltaT(txi,rxi,targeti);
            time = time+delay;
            flag = obj.tx.tx_flags(time-delay,txi); 
            t1 = 2*pi*obj.tx.k*delay*time;
            t2 = -pi*obj.tx.k*delay^2;
            t3 = 2*pi*obj.tx.frequency*delay;
            s = exp(1i*(t1+t2+t3))*flag;
        end 
        % Function to calculate the received signal for a dynamic scatterer
        function s = rxSignal3(obj,time,time2,txi,rxi,targeti)            
            % Doppler Frequency
            vr = obj.target(targeti).rangerate();
            fd = -2*vr/obj.tx.lambda;

            delay = obj.deltaT(txi,rxi,targeti);
            t = time+delay; 
            flag = obj.tx.tx_flags(time,txi);
            t1 = 2*pi*obj.tx.k*delay*t;
            t2 = -pi*obj.tx.k*delay^2;
            t3 = 2*pi*(obj.tx.frequency)*delay;
            t4 = -2*pi*fd*(time2); 

            s = exp(1i*(t1+t2+t3+t4))*flag;
        end
        
        % Optimized function of the received signal, the output is a matrix
        % contaning the received signal during a single chirp for all
        % targets, trasnmitters and receivers 
        % NOT ENABLED FOR MOVING TARGETS FOR NOW (Calculation of Delta T
        % not optimized yet) 
        function [s,timeStamp] = rxSignal4(obj) 
            txN = obj.tx.numberofElements; 
            rxN = obj.rx.numberofElements; 
            targetN = obj.numberofTargets; 
            signalN = obj.tx.samplesPerChirp*txN;
            
            timeStamp = obj.tx.samplingRate:obj.tx.samplingRate:(obj.tx.samplingRate*(signalN));
            time =  reshape(repmat(timeStamp,txN*rxN,1),txN,rxN,signalN); 
            
            s = zeros(size(time)); 
            for i = 1:targetN 
                delay = reshape(repmat(obj.deltaT(:,:,i),signalN,1),txN,rxN,signalN);
                t1 = 2*pi*obj.tx.k*delay.*time; 
                t2 = -pi*obj.tx.k*delay.*delay; 
                t3 = 2*pi*obj.tx.frequency*delay; 
                s = s+exp(1i*(t1+t2+t3)); 
       
            end
            signal = zeros(size(time)); 

            for i=1:txN 
               index = (1+(i-1)*obj.tx.samplesPerChirp):1:i*obj.tx.samplesPerChirp; 
               signal(i,:,index) =  s(i,:,index); 
            end
            
            s = signal;             
        end 
       
        % Functions used to calculate the Azimuth Range
        
        function s = steeringVector(obj,theta,txi,rxi)
           x_tx = [obj.tx.xE(txi),obj.tx.yE(txi),obj.tx.zE(txi)]; 
           x_rx = [obj.rx.xE(rxi),obj.rx.yE(rxi),obj.rx.zE(rxi)]; 
           xij = norm((x_tx+x_rx)/2); 
           s = exp(1i*4*pi*xij*sin(theta)/obj.tx.lambda);  
        end


    end
    
    
end
