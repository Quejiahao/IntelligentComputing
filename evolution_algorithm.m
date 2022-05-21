function [ ...
	xs, ...
	fvals, ...
	... population, ...
	... population_var, ...
	ts, ...
	elapsed_time ...
] = evolution_algorithm()
	clear, clc, close all;
	init_partool(16);
	tic;
	rng('shuffle');
	T = 256;
	fvals = zeros(T, 1);
	nvars = 5;
	xs = zeros(T, nvars);
	ts = zeros(T, 1);
	elapsed_time = zeros(T, 1);
	% for i = 1:T
	parfor i = 1:T
		tic;
		[ ...
			x, ...
			fval, ...
			~, ... population, ...
			~, ... population_var, ...
			t ...
		] = ea( ...
			@f2, ...
			nvars, ...
			-100 .* ones(1, nvars), ...
			100 .* ones(1, nvars), ...
			1, ...
			200, ...
			true, ...
			200000, ...
			eps, ...
			'es' ...
		);
		% [ ...
		% 	x, ...
		% 	fval, ...
		% 	~, ... population, ...
		% 	~, ... population_var, ...
		% 	t ...
		% ] = ea( ...
		% 	@f3, ...
		% 	nvars, ...
		% 	-600 .* ones(1, nvars), ...
		% 	600 .* ones(1, nvars), ...
		% 	30, ...
		% 	27, ...
		% 	true, ...
		% 	200000, ...
		% 	1e-3, ...
		% 	'ep' ...
		% );
		fvals(i) = fval;
		xs(i, :) = x;
		ts(i) = t;
		elapsed_time(i) = toc;
		disp(i);
	end
	toc
	% delete(gcp('nocreate'));
	scatter(xs(:, 1), xs(:, 2));
	% histogram(vecnorm(xs, 2, 2));
	disp(sum(vecnorm(xs, 2, 2) <= 1e-4));
end

function [] = print_result()
	clear, clc, close all;
	filenames = [ ...
		"es_1_plus_1.mat", ...
		"es_1_plus_lambda.mat", ...
		"es_mu_plus_1.mat", ...
		"es_mu_plus_lambda.mat", ...
		"es_mu_lambda.mat", ...
		"ep.mat" ...
		];
	tscmp = [ 1e3, 1e2, 1e4, 1e2, 1e2, 1e2 ];
	for i = 1:length(filenames)
		load(filenames(i));
		figure();
		scatter(xs(:,1), xs(:, 2));
		figure();
		histogram(elapsed_time);
		disp(sum(vecnorm(xs, 2, 2) <= 1e-6));
		disp(sum(ts <= tscmp(i)));
		disp(mean(ts));
		disp(mean(elapsed_time));
	end
end

function init_partool(worker_num)
	c = parcluster;
	c.NumWorkers = worker_num;
	delete(gcp('nocreate'));
	parpool(c.NumWorkers);
end

function fval = f2(x)
	r2 = sum(x .^ 2, 2);
	fval = 0.5 + (sin(sqrt(r2)) .^ 2 - 0.5) ...
				./ (1 + 0.001 * r2 .^ 2);
end

function fval = f3(x)
	fval = sum(x .^ 2, 2) ./ 4000 ...
		- prod(cos(x ./ sqrt( (1 : size(x, 2)) )), 2) + 1;
end

function [population, population_var] = init_population(parent_num, nvars, lb, ub)
	% uniform distribution
	population = rand(parent_num, nvars) .* (ub - lb) + lb;
	population_var = ones(parent_num, nvars) .* 10;
end

function [children, children_var] = recombination(population, population_var)
	% variable: discrete, variation: median
	[parent_num, nvars] = size(population, 1, 2);
	parent_ind = randsample(parent_num, 2);
	parent1_ind = parent_ind(1);
	parent2_ind = parent_ind(2);
	% median may cause linear population, it is bad!
	% children = (population(parent1_ind, :) + population(parent2_ind, :)) ./ 2;
	two_parent = [ ...
		population(parent1_ind, :); ...
		population(parent2_ind, :) ...
	];
	rand_ind = randi([1, 2], nvars, 1);
	children = zeros(1, nvars);
	for i = 1:nvars
		children(i) = two_parent(rand_ind(i), i);
	end
	children_var = (population_var(parent1_ind, :) + population_var(parent2_ind, :)) ./ 2;
end

function [children, children_var] = mutation_binary_representation(parent, parent_var, lb, ub)
	% binary representation
	c1 = 1;
	c2 = 1;
	nvars = size(parent, 2);
	children_var = abs(parent_var ...
		.* exp(c1 / sqrt(2 * nvars) * randn() + c2 / sqrt(2 * sqrt(nvars)) .* randn(1, nvars)));
	children = min(max(parent + randn(1, nvars) .* children_var, lb), ub);
end

function [ ...
	x, ...
	fval, ...
	population, ...
	population_var, ...
	t ...
] = es( ...
	fun, ...
	nvars, ...
	lb, ...
	ub, ...
	... parent_num, ...	% can obtain from population
	children_num, ...	% \lambda
	parent_keep, ...	% (\mu + \lambda) or (\mu, \lambda)
	step_tolerance, ...
	variation_tolerance, ...
	population, ...
	population_var ...
)
	parent_num = size(population, 1);
	fval = min(fun(population(:, :, 1)));
	t = 1;
	while t <= step_tolerance
		children = zeros(children_num, nvars);
		children_var = zeros(children_num, nvars);
		for i = 1:children_num
		% parfor i = 1:children_num
			if parent_num > 1
				[children(i, :), children_var(i, :)] = recombination(population(:, :, t), population_var(:, :, t));
			else
				children(i, :) = population(1, :, t);
				children_var(i, :) = population_var(1, :, t);
			end
			[children(i, :), children_var(i, :)] = mutation_binary_representation(children(i, :), children_var(i, :), lb, ub);
		end

		if parent_keep
			population_temp = [
				population(:, :, t);
				children
			];
			population_temp_var = [
				population_var(:, :, t);
				children_var
			];
		else
			population_temp = children;
			population_temp_var = children_var;
		end
		population_fvals = fun(population_temp);
		[~, I] = mink(population_fvals, parent_num);
		t = t + 1;
		population(:, :, t) = population_temp(I, :);
		population_var(:, :, t) = population_temp_var(I, :);
		population_fvals = population_fvals(I, :);
		% scatter(population(:, 1, t), population(:, 2, t));
		% pause(0.01);

		[fval_min, min_index] = min(population_fvals);
		if size(population, 1) == 1
			if fval_min == fval
				continue;
			end
			fval_max = fval;
		else
			fval_max = max(population_fvals);
		end
		fval = fval_min;
		x = population(min_index, :, t);
		% disp(t);
		if abs(fval_max - fval_min) < variation_tolerance
			t = t - 1;
			% disp(t);
			break;
		end
	end
end

function [children, children_var] = mutation_meta(parent, parent_var, lb, ub)
	% meta evolutionary programming
	nvars = size(parent, 2);
	children = min(max(parent + randn(1, nvars) .* sqrt(parent_var), lb), ub);
	children_var = abs(parent_var ...
		+ randn(1, nvars) .* sqrt(parent_var));
end

function scores = ep_battle_q_scores(population, fun, test_num)
	population_num = size(population, 1);
	scores = zeros(population_num, 1);
	population_fvals = fun(population);
	for i = 1:population_num
		battle_q_index = randsample(population_num, test_num);
		battle_win_bool = (population_fvals(i) <= population_fvals(battle_q_index));
		scores(i) = sum(battle_win_bool);
	end
end

function [ ...
	x, ...
	fval, ...
	population, ...
	population_var, ...
	t ...
] = ep( ...
	fun, ...
	nvars, ...
	lb, ...
	ub, ...
	... parent_num, ...	% can obtain from population
	test_num, ...	% q
	step_tolerance, ...
	variation_tolerance, ...
	population, ...
	population_var ...
)
	parent_num = size(population, 1);
	children_num = parent_num;
	t = 1;
	while t <= step_tolerance
		children = zeros(children_num, nvars);
		children_var = zeros(children_num, nvars);
		for i = 1:children_num
		% parfor i = 1:children_num
			[children(i, :), children_var(i, :)] = mutation_meta(population(1, :, t), population_var(1, :, t), lb, ub);
		end

		population_temp = [
			population(:, :, t);
			children
		];
		population_temp_var = [
			population_var(:, :, t);
			children_var
		];
		[~, I] = maxk(ep_battle_q_scores(population_temp, fun, test_num), parent_num);
		t = t + 1;
		population(:, :, t) = population_temp(I, :);
		population_var(:, :, t) = population_temp_var(I, :);

		population_fvals = fun(population(:, :, t));
		[fval, min_index] = min(population_fvals);
		fval_max = max(population_fvals);
		x = population(min_index, :, t);
		% scatter(population(:, 1, t), population(:, 2, t));
		% pause(0.0000001);
		% disp(t);
		if abs(fval_max - fval) < variation_tolerance
			t = t - 1;
			% disp(t);
			break;
		end
	end
end

function [ ...
	x, ...
	fval, ...
	population, ...
	population_var, ...
	t ...
] = ea( ...
	fun, ...
	nvars, ...
	lb, ...
	ub, ...
	parent_num, ...		% \mu
	children_num, ...	% \lambda or q
	parent_keep, ...	% (\mu + \lambda) or (\mu, \lambda)
	step_tolerance, ...
	variation_tolerance, ...
	algorithm_name ...	% `es` or `ep`
)
	% initial population
	[population_init, population_var_init] ...
		= init_population(parent_num, nvars, lb, ub);
	population = cat(3, ...
		population_init, ...
		zeros(parent_num, nvars, step_tolerance) ...
	);
	population_var = cat(3, ...
		population_var_init, ...
		zeros(parent_num, nvars, step_tolerance) ...
	);

	if strcmp(algorithm_name, 'es')
		[ ...
			x, ...
			fval, ...
			population, ...
			population_var, ...
			t ...
		] = es( ...
			fun, ...
			nvars, ...
			lb, ...
			ub, ...
			... parent_num, ...		% can obtain from population
			children_num, ...	% \lambda
			parent_keep, ...	% (\mu + \lambda) or (\mu, \lambda)
			step_tolerance, ...
			variation_tolerance, ...
			population, ...
			population_var ...
		);
	elseif strcmp(algorithm_name, 'ep')
		[ ...
			x, ...
			fval, ...
			population, ...
			population_var, ...
			t ...
		] = ep( ...
			fun, ...
			nvars, ...
			lb, ...
			ub, ...
			... parent_num, ...		% can obtain from population
			children_num, ...	% \lambda
			step_tolerance, ...
			variation_tolerance, ...
			population, ...
			population_var ...
		);
	else
		error(strcat('No `algorithm_name`: ', algorithm_name));
	end
end
