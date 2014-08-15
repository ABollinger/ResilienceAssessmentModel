%% SET SOME VARIABLES

printstuff = false;
%analysistype = 2;

%mpc = loadcase('case9');
%mpc = loadcase('case14');
%mpc = loadcase('case118');
%mpc = loadcase('testcase2');

%generatorcosts = 1:length(mpc.gen(:,1));

%% CREATE THE ADJACENCY MATRIX

% construct the adjacency matrix from the bus and branch data
adjacencymatrix = zeros(length(mpc.bus(:,1)),length(mpc.bus(:,1)));
for x = 1:size(mpc.branch(:,1))
    adjacencymatrix(mpc.branch(x,1), mpc.branch(x,2)) = 1;
    adjacencymatrix(mpc.branch(x,2), mpc.branch(x,1)) = 1;
end

% add ones to the diagonal of the adjacency matrix
for x = 1:length(adjacencymatrix)
    adjacencymatrix(x,x) = 1;
end

%% RUN THE LOAD FLOW

% create some vectors/matrices for use later
numrows = length(mpc.branch(:,1));
contingencyresults = horzcat(mpc.branch(:,1:2),zeros(numrows,3));
mpopt = mpoption('PF_DC', 1, 'OUT_ALL', 0, 'VERBOSE', 0);
%mpopt = mpoption('PF_DC', 1);

generatorresults = mpc.gen(:,1:2);
generatorresults(:,2) = 0;

% the network might be composed of multiple isolated components
% to deal with this, we first identify the nodes belonging to the different components
m = adjacencymatrix;
[p,q,r,s] = dmperm(m);
components = zeros(length(r) - 1, numrows);
for y = 2:length(r)
    nodevector = p(r(y - 1):r(y) - 1);
    for z = 1:length(nodevector)
        components(y-1, z) = nodevector(z);
    end
end

if printstuff == true
    disp('components = ');
    disp(components);
end

% for each component
for component = 1:length(components(:,1))

    % create a vector of the nodes in the component
    nodesinthiscomponent = nonzeros(components(component,:));

    % create some empty matrices for the power flow analysis
    mpc2.bus = [];
    mpc2.gen = [];
    mpc2.branch = [];

    % fill the power flow analysis matrices
    for currentnode = 1:length(nodesinthiscomponent)
        mpc2.bus = vertcat(mpc2.bus, mpc.bus(nodesinthiscomponent(currentnode),:));
        mpc2.gen = vertcat(mpc2.gen, mpc.gen(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:)); 

        for othernode = 1:length(nodesinthiscomponent)
            mpc2.branch = vertcat(mpc2.branch, mpc.branch(find(mpc.branch(:,1) == nodesinthiscomponent(currentnode) & mpc.branch(:,2) == nodesinthiscomponent(othernode) & mpc.branch(:,11) == 1),:));
        end
    end

    % remove duplicate entries in the new branch matrix
    mpc2.branch = unique(mpc2.branch, 'rows');

    if printstuff == true
        disp('bus list = ');
        disp(mpc2.bus);
        disp('gen list = ');
        disp(mpc2.gen);
        disp('branch list = ');
        disp(mpc2.branch);
    end
    
    % reset the demand of the buses in case there is not enough
    % generation capacity
    totalgenerationcapacityinthiscomponent = sum(mpc2.gen(:,9));
    totalloadinthiscomponent = sum(mpc2.bus(:,3));
    if totalgenerationcapacityinthiscomponent < totalloadinthiscomponent
        mpc2.bus(:,3) = mpc2.bus(:,3) * totalgenerationcapacityinthiscomponent / totalloadinthiscomponent;
    end
    
    % initially set the bus types of all buses to 1
    mpc2.bus(:,2) = 1;
    
    % set the bus types of all buses with generators attached to 2
    buseswithgeneratorsattached = [];
    numbersofbuseswithattachedgenerators = mpc2.gen(:,1);
    for j = 1:length(numbersofbuseswithattachedgenerators)
        buseswithgeneratorsattached = vertcat(buseswithgeneratorsattached, find(mpc2.bus(:,1) == numbersofbuseswithattachedgenerators(j)));
    end
    mpc2.bus(buseswithgeneratorsattached,2) = 2;
    
    %identify the isolated buses and set their bus types = 4
    %isolated buses are buses with no attached demand, no attached 
    %generators and only one attached line
    buseswithnodemand = find(mpc2.bus(:,3) == 0); 
    buseswithnogenerators = find(mpc2.bus(:,2) == 1);
    isolatedbuses = intersect(buseswithnodemand, buseswithnogenerators);

    buseswithonebranch = [];
    busnumbers = mpc2.bus(:,1);
    for currentbus = 1:length(busnumbers)
        countoccurrences = sum(mpc2.branch(:,1) == busnumbers(currentbus));
        countoccurrences = countoccurrences + sum(mpc2.branch(:,2) == busnumbers(currentbus));
        if countoccurrences == 1
           buseswithonebranch = vertcat(buseswithonebranch, find(mpc2.bus(:,1) == busnumbers(currentbus)));
        end
    end
    isolatedbuses = intersect(isolatedbuses, buseswithonebranch);
    mpc2.bus(isolatedbuses,2) = 4;

    % if there are generators and branches in this component
    if length(find(mpc2.bus(:,2) == 2)) > 0 && length(mpc2.branch(:,1)) > 0 && length(find(mpc2.bus(:,2) ~= 4)) > 1

        % if there is no slack bus, create one
        if length(find(mpc2.bus(:,2) == 3)) == 0  
            buseswithgenerators = find(mpc2.bus(:,2) == 2);
            mpc2.bus(buseswithgenerators(1),2) = 3;
        end
        
        % fill in the missing matrices for the power flow analysis
        mpc2.version = mpc.version;
        mpc2.baseMVA = mpc.baseMVA;
        %mpc2.areas = mpc.areas;

        % run the power flow analysis and save the results
        results = runpf(mpc2, mpopt);

        branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
        branchinjectedfromend = results.branch(:,14);
        branchinjectedtoend = results.branch(:,16);
        branchresults = horzcat(mpc2.branch(:,1:2), branchinjectedfromend, branchinjectedtoend, branchflows);
        
        generatorresults = results.gen(:,1:2);

        if printstuff == true
            disp('branch results = ');
            disp(branchresults);
        end

        % fill the contingency analysis results matrix with the
        % results of the power flow analysis for this component
        for y = 1:length(branchresults(:,1))
            for z = 1:length(contingencyresults(:,1))
                if branchresults(y,1) == contingencyresults(z,1) & branchresults(y,2) == contingencyresults(z,2)
                    if branchresults(y,5) > contingencyresults(z,5) 
                        contingencyresults(z,5) = branchresults(y,5);
                        contingencyresults(z,4) = branchresults(y,4);
                        contingencyresults(z,3) = branchresults(y,3);
                    end
                end
            end
        end
    end
end


%% N-1 CONTINGENCY ANALYSIS

if analysistype == 1 
    
    generatorcosts = generatorcosts';
    iteration = 0;

    % iterate through the branches, removing each one in turn
    for x = 1:numrows

        if printstuff == true
            disp('removed line = ');
            disp(x);
        end

        % remove the branch by setting the status (column 11) to 0
        mpc.branch(x,11) = 0;

        % edit the adjacency matrix to reflect the removal of this link
        m = adjacencymatrix;
        bus1 = mpc.branch(x,1);
        bus2 = mpc.branch(x,2);
        m(bus1,bus2) = 0;
        m(bus2,bus1) = 0;

        % identify the nodes belonging to the different components
        [p,q,r,s] = dmperm(m);
        components = zeros(length(r) - 1, numrows);
        for y = 2:length(r)
            nodevector = p(r(y - 1):r(y) - 1);
            for z = 1:length(nodevector)
                components(y-1, z) = nodevector(z);
            end
        end

        if printstuff == true
            disp('components = ');
            disp(components);
        end

        % for each component
        for component = 1:length(components(:,1))

            % create a vector of the nodes in the component
            nodesinthiscomponent = nonzeros(components(component,:));

            % create some empty matrices for the power flow analysis
            mpc2.bus = [];
            mpc2.gen = [];
            mpc2.branch = [];
            generatorcosts2 = [];

            % fill the power flow analysis matrices
            for currentnode = 1:length(nodesinthiscomponent)
                mpc2.bus = vertcat(mpc2.bus, mpc.bus(nodesinthiscomponent(currentnode),:));
                mpc2.gen = vertcat(mpc2.gen, mpc.gen(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:)); 
                generatorcosts2 = vertcat(generatorcosts2, generatorcosts(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:));

                for othernode = 1:length(nodesinthiscomponent)
                    mpc2.branch = vertcat(mpc2.branch, mpc.branch(find(mpc.branch(:,1) == nodesinthiscomponent(currentnode) & mpc.branch(:,2) == nodesinthiscomponent(othernode) & mpc.branch(:,11) == 1),:));
                end
            end

            % remove duplicate entries in the new branch matrix
            mpc2.branch = unique(mpc2.branch, 'rows');

            if printstuff == true
                disp('bus list = ');
                disp(mpc2.bus);
                disp('gen list = ');
                disp(mpc2.gen);
                disp('branch list = ');
                disp(mpc2.branch);
            end
            
            % set the real power output for each generator
            % initially set the real power output of all plants to 0
            mpc2.gen(:,2) = 0;

            generatorindices = 1:length(mpc2.gen(:,1));
            generatorindices = generatorindices';
            randomindices = randperm(length(mpc2.gen(:,1)));
            randomindices = randomindices';

            % create a temporary list for assigning the outputs
            tempgenlist = horzcat(randomindices, generatorindices, mpc2.gen(:,2), mpc2.gen(:,9), generatorcosts2);

            % sort the list, first according to the random indices, then according
            % to the generator costs
            tempgenlist = sortrows(tempgenlist, 1);
            tempgenlist = sortrows(tempgenlist, 5);

            % choose the plant at the top of the list and set the power output
            remainingdemand = sum(mpc2.bus(:,3));
            for generator = 1:length(tempgenlist(:,1))
                remainingsupply = tempgenlist(generator,4);
                if remainingsupply >= remainingdemand
                    remainingsupply = remainingsupply - remainingdemand;
                    tempgenlist(generator,3) = remainingdemand;
                    remainingdemand = 0;
                else    
                    remainingdemand = remainingdemand - remainingsupply;
                    tempgenlist(generator,3) = remainingsupply;
                    remainingsupply = 0;
                end
            end

            % put the list back in its original order and assign the generator
            % output values
            tempgenlist = sortrows(tempgenlist, 2);
            mpc2.gen(:,2) = tempgenlist(:,3);

            % reset the demand of the buses in case there is not enough
            % generation capacity
            totalgenerationcapacityinthiscomponent = sum(mpc2.gen(:,9));
            totalloadinthiscomponent = sum(mpc2.bus(:,3));
            if totalgenerationcapacityinthiscomponent < totalloadinthiscomponent
                mpc2.bus(:,3) = mpc2.bus(:,3) * totalgenerationcapacityinthiscomponent / totalloadinthiscomponent;
            end
            
            % initially set the bus types of all buses to 1
            mpc2.bus(:,2) = 1;

            % set the bus types of all buses with generators attached to 2
            buseswithgeneratorsattached = [];
            numbersofbuseswithattachedgenerators = mpc2.gen(:,1);
            for j = 1:length(numbersofbuseswithattachedgenerators)
                buseswithgeneratorsattached = vertcat(buseswithgeneratorsattached, find(mpc2.bus(:,1) == numbersofbuseswithattachedgenerators(j)));
            end
            mpc2.bus(buseswithgeneratorsattached,2) = 2;
            
            %identify the isolated buses and set their bus types = 4
            %isolated buses are buses with no attached demand, no attached 
            %generators and only one attached line
            buseswithnodemand = find(mpc2.bus(:,3) == 0); 
            buseswithnogenerators = find(mpc2.bus(:,2) == 1);
            isolatedbuses = intersect(buseswithnodemand, buseswithnogenerators);

            buseswithonebranch = [];
            busnumbers = mpc2.bus(:,1);
            for currentbus = 1:length(busnumbers)
                countoccurrences = sum(mpc2.branch(:,1) == busnumbers(currentbus));
                countoccurrences = countoccurrences + sum(mpc2.branch(:,2) == busnumbers(currentbus));
                if countoccurrences == 1
                   buseswithonebranch = vertcat(buseswithonebranch, find(mpc2.bus(:,1) == busnumbers(currentbus)));
                end
            end
            isolatedbuses = intersect(isolatedbuses, buseswithonebranch);
            mpc2.bus(isolatedbuses,2) = 4;

            % if there are generators and branches in this component
            if length(find(mpc2.bus(:,2) == 2)) > 0 && length(mpc2.branch(:,1)) > 0 && length(find(mpc2.bus(:,2) ~= 4)) > 1

                % if there is no slack bus, create one
                if length(find(mpc2.bus(:,2) == 3)) == 0  
                    buseswithgenerators = find(mpc2.bus(:,2) == 2);
                    mpc2.bus(buseswithgenerators(1),2) = 3;
                end

                % fill in the missing matrices for the power flow analysis
                mpc2.version = mpc.version;
                mpc2.baseMVA = mpc.baseMVA;
                %mpc2.areas = mpc.areas;

                % run the power flow analysis and save the results
                results = runpf(mpc2, mpopt);

                branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
                branchinjectedfromend = results.branch(:,14);
                branchinjectedtoend = results.branch(:,16);
                branchresults = horzcat(mpc2.branch(:,1:2), branchinjectedfromend, branchinjectedtoend, branchflows);
                
                if printstuff == true
                    disp('branch results = ');
                    disp(branchresults);
                end

                % fill the contingency analysis results matrix with the
                % results of the power flow analysis for this component
                for y = 1:length(branchresults(:,1))
                    for z = 1:length(contingencyresults(:,1))
                        if branchresults(y,1) == contingencyresults(z,1) & branchresults(y,2) == contingencyresults(z,2)
                            if branchresults(y,5) > contingencyresults(z,5) 
                                contingencyresults(z,5) = branchresults(y,5);
                                contingencyresults(z,4) = branchresults(y,4);
                                contingencyresults(z,3) = branchresults(y,3);
                            end
                        end
                    end
                end
            end
        end

        iteration = iteration + 1;
        if printstuff == true
            disp('iteration =');
            disp(iteration);
        end

        % replace the removed branch by setting the status (column 11) back to 1
        mpc.branch(x,11) = 1;
    end
end

%% N-2 CONTINGENCY ANALYSIS

if analysistype == 2

   iteration = 0;
   generatorcosts = generatorcosts';

    % iterate through the branches, removing each one in turn
    for x = 1:numrows

        % remove the branch by setting the status (column 11) to 0
        mpc.branch(x,11) = 0;

        for w = 1:numrows

            if printstuff == true
                disp('removed lines = ');
                disp(x);
                disp(w);
            end

            % remove the branch by setting the status (column 11) to 0
            mpc.branch(w,11) = 0;

            % edit the adjacency matrix to reflect the removal of the links
            m = adjacencymatrix;

            bus1 = mpc.branch(x,1);
            bus2 = mpc.branch(x,2);
            m(bus1,bus2) = 0;
            m(bus2,bus1) = 0;

            bus3 = mpc.branch(w,1);
            bus4 = mpc.branch(w,2);
            m(bus3,bus4) = 0;
            m(bus4,bus3) = 0;

            % identify the nodes belonging to the different components
            [p,q,r,s] = dmperm(m);
            components = zeros(length(r) - 1, numrows);
            for y = 2:length(r)
                nodevector = p(r(y - 1):r(y) - 1);
                for z = 1:length(nodevector)
                    components(y-1, z) = nodevector(z);
                end
            end

            if printstuff == true
                disp('components = ');
                disp(components);
            end

            % for each component
            for component = 1:length(components(:,1))

                % create a vector of the nodes in the component
                nodesinthiscomponent = nonzeros(components(component,:));

                % create some empty matrices for the power flow analysis
                mpc2.bus = [];
                mpc2.gen = [];
                mpc2.branch = [];
                generatorcosts2 = [];

                % fill the power flow analysis matrices
                for currentnode = 1:length(nodesinthiscomponent)
                    mpc2.bus = vertcat(mpc2.bus, mpc.bus(nodesinthiscomponent(currentnode),:));
                    mpc2.gen = vertcat(mpc2.gen, mpc.gen(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:));
                    generatorcosts2 = vertcat(generatorcosts2, generatorcosts(find(mpc.gen(:,1) == nodesinthiscomponent(currentnode)),:));

                    for othernode = 1:length(nodesinthiscomponent)
                        mpc2.branch = vertcat(mpc2.branch, mpc.branch(find(mpc.branch(:,1) == nodesinthiscomponent(currentnode) & mpc.branch(:,2) == nodesinthiscomponent(othernode) & mpc.branch(:,11) == 1),:));
                    end
                end

                % remove duplicate entries in the new branch matrix
                mpc2.branch = unique(mpc2.branch, 'rows');

                if printstuff == true
                    disp('bus list = ');
                    disp(mpc2.bus);
                    disp('gen list = ');
                    disp(mpc2.gen);
                    disp('branch list = ');
                    disp(mpc2.branch);
                end
                
                % set the real power output for each generator
                % initially set the real power output of all plants to 0
                mpc2.gen(:,2) = 0;

                generatorindices = 1:length(mpc2.gen(:,1));
                generatorindices = generatorindices';
                randomindices = randperm(length(mpc2.gen(:,1)));
                randomindices = randomindices';

                % create a temporary list for assigning the outputs
                tempgenlist = horzcat(randomindices, generatorindices, mpc2.gen(:,2), mpc2.gen(:,9), generatorcosts2);

                % sort the list, first according to the random indices, then according
                % to the generator costs
                tempgenlist = sortrows(tempgenlist, 1);
                tempgenlist = sortrows(tempgenlist, 5);

                % choose the plant at the top of the list and set the power output
                remainingdemand = sum(mpc2.bus(:,3));
                for generator = 1:length(tempgenlist(:,1))
                    remainingsupply = tempgenlist(generator,4);
                    if remainingsupply >= remainingdemand
                        remainingsupply = remainingsupply - remainingdemand;
                        tempgenlist(generator,3) = remainingdemand;
                        remainingdemand = 0;
                    else    
                        remainingdemand = remainingdemand - remainingsupply;
                        tempgenlist(generator,3) = remainingsupply;
                        remainingsupply = 0;
                    end
                end

                % put the list back in its original order and assign the generator
                % output values
                tempgenlist = sortrows(tempgenlist, 2);
                mpc2.gen(:,2) = tempgenlist(:,3);

                % reset the demand of the buses in case there is not enough
                % generation capacity
                totalgenerationcapacityinthiscomponent = sum(mpc2.gen(:,9));
                totalloadinthiscomponent = sum(mpc2.bus(:,3));
                if totalgenerationcapacityinthiscomponent < totalloadinthiscomponent
                    mpc2.bus(:,3) = mpc2.bus(:,3) * totalgenerationcapacityinthiscomponent / totalloadinthiscomponent;
                end

                % initially set the bus types of all buses to 1
                mpc2.bus(:,2) = 1;

                % set the bus types of all buses with generators attached to 2
                buseswithgeneratorsattached = [];
                numbersofbuseswithattachedgenerators = mpc2.gen(:,1);
                for j = 1:length(numbersofbuseswithattachedgenerators)
                    buseswithgeneratorsattached = vertcat(buseswithgeneratorsattached, find(mpc2.bus(:,1) == numbersofbuseswithattachedgenerators(j)));
                end
                mpc2.bus(buseswithgeneratorsattached,2) = 2;
                
                %identify the isolated buses and set their bus types = 4
                %isolated buses are buses with no attached demand, no attached 
                %generators and only one attached line
                buseswithnodemand = find(mpc2.bus(:,3) == 0); 
                buseswithnogenerators = find(mpc2.bus(:,2) == 1);
                isolatedbuses = intersect(buseswithnodemand, buseswithnogenerators);

                buseswithonebranch = [];
                busnumbers = mpc2.bus(:,1);
                for currentbus = 1:length(busnumbers)
                    countoccurrences = sum(mpc2.branch(:,1) == busnumbers(currentbus));
                    countoccurrences = countoccurrences + sum(mpc2.branch(:,2) == busnumbers(currentbus));
                    if countoccurrences == 1
                       buseswithonebranch = vertcat(buseswithonebranch, find(mpc2.bus(:,1) == busnumbers(currentbus)));
                    end
                end
                isolatedbuses = intersect(isolatedbuses, buseswithonebranch);
                mpc2.bus(isolatedbuses,2) = 4;

                % if there are generators and branches in this component
                if length(find(mpc2.bus(:,2) == 2)) > 0 && length(mpc2.branch(:,1)) > 0 && length(find(mpc2.bus(:,2) ~= 4)) > 1

                    % if there is no slack bus, create one
                    if length(find(mpc2.bus(:,2) == 3)) == 0  
                        buseswithgenerators = find(mpc2.bus(:,2) == 2);
                        mpc2.bus(buseswithgenerators(1),2) = 3;
                    end

                    % fill in the missing matrices for the power flow analysis
                    mpc2.version = mpc.version;
                    mpc2.baseMVA = mpc.baseMVA;
                    %mpc2.areas = mpc.areas;

                    % run the power flow analysis and save the results
                    results = runpf(mpc2, mpopt);

                    branchflows = max(abs(results.branch(:,14)), abs(results.branch(:,16)));
                    branchinjectedfromend = results.branch(:,14);
                    branchinjectedtoend = results.branch(:,16);
                    branchresults = horzcat(mpc2.branch(:,1:2), branchinjectedfromend, branchinjectedtoend, branchflows);

                    if printstuff == true
                        disp('branch results = ');
                        disp(branchresults);
                    end

                    % fill the contingency analysis results matrix with the
                    % results of the power flow analysis for this component
                    for y = 1:length(branchresults(:,1))
                        for z = 1:length(contingencyresults(:,1))
                            if branchresults(y,1) == contingencyresults(z,1) & branchresults(y,2) == contingencyresults(z,2)
                                if branchresults(y,5) > contingencyresults(z,5) 
                                    contingencyresults(z,5) = branchresults(y,5);
                                    contingencyresults(z,4) = branchresults(y,4);
                                    contingencyresults(z,3) = branchresults(y,3);
                                end
                            end
                        end
                    end
                end
            end

            iteration = iteration + 1;
            if printstuff == true
                disp('iteration =');
                disp(iteration);
            end

            % replace the removed branch by setting the status (column 11)
            % back to 1
            mpc.branch(w,11) = 1;
        end

        % replace the removed branch by setting the status (column 11) back to 1
        mpc.branch(x,11) = 1;
    end
end
