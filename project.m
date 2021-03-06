import functools.*

warning off;
clear;
clc;
close all;

tic;

% Zmienne pomocnicze
k_cross_validation = 5;
test_percentage = 1.0/k_cross_validation; % this is 20%
learning_percentage = 1 - test_percentage;
it = k_cross_validation;

bound_perc = 0.2;

Description = strings(it, 1);
SC_u = zeros(it, 1);
PSO_u = zeros(it, 1);
SC_t = zeros(it, 1);
PSO_t = zeros(it, 1);


% % Inicjalizacja zbioru (iris)  --------------------------------
% dataset = readmatrix('./datasets/iris.csv');
% [n, ~] = size(dataset);
% % --------------------------------------------------------------

% % Inicjalizacja zbioru (seeds)  --------------------------------
% dataset = readmatrix('./datasets/seeds.csv');
% [n, ~] = size(dataset);
% % --------------------------------------------------------------

% Inicjalizacja zbioru (wine) --------------------------------
datasetRaw = readmatrix('./datasets/wine.csv');
% dataset = [dataset(:,2:end),dataset(:,1)];
datasetCorrectedColumns = [datasetRaw(:,2:end),datasetRaw(:,1)];
dataset = [datasetCorrectedColumns(:, [4,6,7,9,11,12, end])];
%     this data was taken from 
%     https://towardsdatascience.com/4-ways-to-reduce-dimensionality-of-data-8f82e6565a07
%
%		nazwa					coefficient		index	
%     {'Flavanoids'     }        0.72525    	7
%     {'OD280'          }        0.60757    	12
%     {'Total_Phenols'  }         0.5904    	6
%     {'Hue'            }        0.47923    	11
%     {'Proanthocyanins'}        0.45022    	9
%     {'Ash_Alcanity'   }         0.4494 		4
% --------------------------------------------------------------

dataset = dataset(randperm(size(dataset, 1)), :); % Randomizacja (mieszanie) datasetu
for loop = 1:it
    [x_u, y_u] = initLearningSet(dataset, test_percentage, loop);
    [x_t, y_t] = initTestingSet(dataset, test_percentage, loop);
    fprintf('Iteracja: %d\n', loop);
    Description(loop) = convertCharsToStrings(sprintf('Iteracja: %d (%%)', loop));

    [SC_u(loop), SC_t(loop), fis] = substractiveClusteringPart(x_u, y_u, x_t, y_t);
    
    [in, out] = getTunableSettings(fis); % Pobranie parametr??w FIS (na potrzeby PSO)
    %paramVals = getTunableValues(fis, [in; out]);

    % Ilo???? parametr??w funkcji przynale??no??ci na ka??dym wej??ciu
    bound_in = getBoundIn(fis.Inputs, size(dataset, 2) -1);
    [lb, ub] = getPSOborders(size(dataset, 2) -1, fis.Inputs, bound_in, bound_perc);

    % Wywo??anie PSO
    close all;
    options = optimoptions('particleswarm', 'PlotFcns', @pswplotbestf, ...
        'SwarmSize', 20, 'MaxIterations', 100, 'MaxStallIterations', 20, 'UseParallel', true);
    options.HybridFcn = @fmincon;
    partiallyAppliedFitness = partial(@fitness, fis, x_u, y_u);
    x = particleswarm(partiallyAppliedFitness, sum(bound_in), lb, ub, options);
        % particleswarm(fun,nvars) attempts to find a vector x 
        % that achieves a local minimum of fun. 
        % nvars is the dimension (number of design variables) of fun.

    % Inicjalizacja FIS na podstawie danych otrzymanych z PSO
    fis = setTunableValues(fis, in, x);
    y_out = evalfis(fis, x_u);
    y_test = evalfis(fis, x_t);
%     fuzzy(fis);

    disp("Particle Swarm Optimization - Fuzzy Inference System");
    correctlyClassifiedLearning = getCorrectlyClassifiedPercent(y_out, y_u);
    fprintf('correctly classified samples in learning set: %.2f%%\n', correctlyClassifiedLearning);
    PSO_u(loop) = correctlyClassifiedLearning;

    correctlyClassifiedTesting = getCorrectlyClassifiedPercent(y_test, y_t);
    fprintf('correctly classified samples in testing set: %.2f%%\n', correctlyClassifiedTesting);
    PSO_t(loop) = correctlyClassifiedTesting;
    
    showChart(y_out, y_u, y_test, y_t);
    fprintf('\n\n');
end

[Description, SC_u, SC_t, PSO_u, PSO_t] = appendMean(Description, SC_u, SC_t, PSO_u, PSO_t, it);
[Description, SC_u, SC_t, PSO_u, PSO_t] = appendStD(Description, SC_u, SC_t, PSO_u, PSO_t, it);

result = table(Description, SC_u, PSO_u, SC_t, PSO_t);
fprintf('Result:\n');
disp(result);

toc;

function fitnessResult = fitness(fis, x_u, y_u, x)
    fis = setTunableValues(fis, getTunableSettings(fis), x);
    y_pso = evalfis(fis, x_u);
    incorrectlyClassified = 1 - size(getQ(y_pso, y_u), 1) / size(y_pso, 1);
    % incorrectlyClassified is value in range [0:1], therefore power to 0.1 will increase
    % difference as the values get closer to 0
    fitnessResult = power(incorrectlyClassified, 0.1); 
end

function q = getQ(y, y_correct)
	q = find( (round(y) - y_correct) == 0);
end

function percent = getCorrectlyClassifiedPercent(y, y_correct)
   percent = 100 * size(getQ(y, y_correct), 1) / size(y, 1);
end

%%% Ilo???? parametr??w funkcji przynale??no??ci na ka??dym wej??ciu
function bound_in = getBoundIn(fisInputs, datasetSize)
	bound_in = zeros(1, datasetSize);
    parfor i = 1:datasetSize
        temp = fisInputs(i).MembershipFunctions.Parameters;
        bound_in(i) = size(fisInputs(i).MembershipFunctions, 2) * size(temp, 2);
    end
end

function [currentSC_u, currentSC_t, fis] = substractiveClusteringPart(x_u, y_u, x_t, y_t)
    fis = genfis(x_u, y_u, genfisOptions('SubtractiveClustering'));
    % fuzzy(fis);
    disp("SubtractiveClustering - Fuzzy Inference System");
    y_out = evalfis(fis, x_u);
    correctlyClassifiedLearning = getCorrectlyClassifiedPercent(y_out, y_u);
    fprintf('correctly classified samples in learning set: %.2f%%\n', correctlyClassifiedLearning);
    currentSC_u = correctlyClassifiedLearning;

    y_test = evalfis(fis, x_t);
    correctlyClassifiedTesting = getCorrectlyClassifiedPercent(y_test, y_t);
    fprintf('correctly classified samples in testing set: %.2f%%\n', correctlyClassifiedTesting);
    currentSC_t = correctlyClassifiedTesting;

    showChart(y_out, y_u, y_test, y_t);
end

function showChart(y_out, y_u, y_test, y_t)
    figure;
    subplot(2, 1, 1)
    scatter(1:length(y_out), round(y_out), 55, 'cyan', 'd')
    hold on;
    scatter(1:length(y_u), round(y_u), 'red', 'filled')
    legend('ymodel', 'yreal')
    title('learning set');
    subplot(2, 1, 2)
    scatter(1:length(y_test), round(y_test), 55, 'm', '*')
    hold on;
    scatter(1:length(y_t), round(y_t), 'b')
    legend('ymodel', 'yreal')
    title('testing set');
end

function [lb, ub] = getPSOborders(datasetSize, fisInputs, bound_in, bound_perc)
    lb = zeros(1, datasetSize * bound_in(1));
    ub = zeros(1, datasetSize * bound_in(1));
    for r = 1:datasetSize
        lbValue = fisInputs(r).Range(1) * (1 - bound_perc);
        ubValue = fisInputs(r).Range(2) * (1 + bound_perc);
        for i = 1:bound_in
            index = (r-1)*bound_in(1) + i;
            lb(index) = lbValue;
            ub(index) = ubValue;
        end
    end
end

function [testStartIndex, testEndIndex] = getTestStartEndIndex(n, testPercentage, loop)
    testingAmount = floor(n * testPercentage); % using floor to convert to int    
    testStartIndex = 1 + (loop-1) * testingAmount; 
    testEndIndex = testStartIndex + testingAmount -1;
end

function [x_u, y_u] = initLearningSet(dataset, testPercentage, loop)
	[n, ~] = size(dataset);
    [startIndex, endIndex] = getTestStartEndIndex(n, testPercentage, loop);
    x_u = dataset([1:startIndex-1, endIndex+1:end], 1:end-1);
    y_u = dataset([1:startIndex-1, endIndex+1:end], end);
end

function [x_t, y_t] = initTestingSet(dataset, testPercentage, loop)
    [n, ~] = size(dataset);
    [startIndex, endIndex] = getTestStartEndIndex(n, testPercentage, loop);
    x_t = dataset(startIndex:endIndex, 1:end-1);
    y_t = dataset(startIndex:endIndex, end);
end

function [Description, SC_u, SC_t, PSO_u, PSO_t] = appendMean(Description, SC_u, SC_t, PSO_u, PSO_t, it)
	Description(end+1) = "??rednie (%)";
	SC_u(end+1) = mean(SC_u(1:it));
	SC_t(end+1) = mean(SC_t(1:it));
	PSO_u(end+1) = mean(PSO_u(1:it));
	PSO_t(end+1) = mean(PSO_t(1:it));
end


function [Description, SC_u, SC_t, PSO_u, PSO_t] = appendStD(Description, SC_u, SC_t, PSO_u, PSO_t, it)
	Description(end+1) = "Odchylenie std";
    SC_u(end+1) = std(SC_u(1:it));
    SC_t(end+1) = std(SC_t(1:it));
    PSO_u(end+1) = std(PSO_u(1:it));
    PSO_t(end+1) = std(PSO_t(1:it));
end
