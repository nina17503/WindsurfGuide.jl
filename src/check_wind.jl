"""
check_level(guidelines, df_wind, level, i)

    Checks which level was given in the input and saves the specific recommendation unter current.

    Arguments:
        guidelines: The DataFrame containing the guidelines.
        df_wind: The DataFrame containing the wind forecast.
        level: The given skill level (valid levels are "beginner", "intermediate", or "advanced").
        i: The row index determining the time that is currently checked.

    Returns:
        The recommendation based on skill level under current as a string.
"""
function check_level(guidelines, df_wind, level, i)

    current = nothing

    for j in 1:size(guidelines, 1)

        if guidelines."max_knots"[j] > df_wind.windspeed_10m[i] >= guidelines."min_knots"[j]

            if level == "beginner"
                current = guidelines."beginner"[j]

            elseif level == "intermediate"
                current = guidelines."intermediate"[j]

            elseif level == "advanced"
                current = guidelines."advanced"[j]

            end
        end
    end

    return current

end

"""
directions(coast)

    Creates a DataFrame containing the wind direction categories relative to the given coast direction.

    Arguments:
        coast:  The direction in degrees in which the coast is facing (pointing towards the sea).
                Must be between 0 and 359.99... degrees.

    Returns:
        The DataFrame containing the wind direction categories as well as the calculated angles.
"""
function directions(coast)
    
    df_dir = DataFrame(
            dir = ["offshore", "crossshore", "cross-onshore", "onshore", "cross-onshore", "crossshore"],
            start = [coast+110, coast+67.5, coast+22.5, coast-22.5, coast-67.5, coast-110],
            stop = [coast-110, coast+110, coast+67.5, coast+22.5, coast-22.5, coast-67.5])
    
    if coast >= 360 || coast < 0
        error("Please choose a valid coast direction angle.")
    else
        for variable in ["start", "stop"]
            df_dir[!, variable] .= mod.(df_dir[!, variable], 360)
        end
    end

    return df_dir

end

"""
check_direction(df_wind, coast, level)

    Determines the wind direction category for each time point of the forecast data, relative to the coast direction.
    The category is then converted into a recommendation based on the users skill level.

    Arguments:
        df_wind: DataFrame containing the forecast data.
        coast:  The direction in degrees in which the coast is facing (pointing towards the sea).
                Must be between 0 and 359.99... degrees.
        level: The given skill level (valid levels are "beginner", "intermediate", or "advanced").

    Returns:
        A vector containing the recommendation for each time point as a string.
"""
function check_direction(df_wind, coast, level)

    results_direction = String[]
    df_dir = directions(coast)

    for i in 1:size(df_wind, 1)
        for j in 1:size(df_dir, 1)
            if df_dir."start"[j] <= df_dir."stop"[j]
                if df_dir."start"[j] <= df_wind."wind_direction_10m"[i] < df_dir."stop"[j]
                    push!(results_direction, df_dir."dir"[j])
                end
            else
                if df_wind."wind_direction_10m"[i] >= df_dir."start"[j] || df_wind."wind_direction_10m"[i] < df_dir."stop"[j]
                    push!(results_direction, df_dir."dir"[j])
                end
            end
        end
        if results_direction[i] == "offshore"
            if level == "beginner" || level == "intermediate"
                results_direction[i] = "Offshore wind, consider waiting for better conditions."
            elseif level == "advanced"
                results_direction[i] = "Offshore wind, be careful!"
            end
        elseif results_direction[i] == "onshore"
            if level == "beginner"
                results_direction[i] = "Onshore wind, very good for your skill level."
            elseif level == "intermediate" || level == "advanced"
                results_direction[i] = "Onshore wind, good for windsurfing."
            end
        elseif results_direction[i] == "crossshore"
            results_direction[i] = "Crossshore wind, very good for all levels."
        elseif results_direction[i] == "cross-onshore"
            results_direction[i] = "Cross-onshore wind, very good for all levels."
        end
    end

    return results_direction

end

"""
check_gusts(df_wind, level)

    Checks the difference between the forecast windspeed and gusts for each time point and gives
    a recommendation based on the users skill level.

    Arguments:
        df_wind: DataFrame containing the forecast data.
        level: The given skill level (valid levels are "beginner", "intermediate", or "advanced").

    Returns:
        A vector containing the recommendation for each time point as a string.
"""
function check_gusts(df_wind, level)

    results_gusts = String[]

    for i in 1:size(df_wind, 1)
        if df_wind."windspeed_10m"[i] >= 10
            if level == "beginner" && df_wind."wind_gusts_10m"[i] >= df_wind."windspeed_10m"[i] + 8
                push!(results_gusts, "The wind gusts are too strong for your skill level, consider waiting for better conditions.")
            elseif level == "intermediate" && df_wind."wind_gusts_10m"[i] >= df_wind."windspeed_10m"[i] + 12
                push!(results_gusts, "The wind gusts are too strong for your skill level, consider waiting for better conditions.")
            elseif level == "advanced" && df_wind."wind_gusts_10m"[i] >= df_wind."windspeed_10m"[i] + 15
                push!(results_gusts, "There are strong wind gusts, choose equipment accordingly.")
            else
                push!(results_gusts, "Wind conditions are mostly stable, gusts are not too strong.")
            end
        else
            push!(results_gusts, "Wind conditions are mostly stable, gusts are not too strong.")
        end
    end

    return results_gusts

end

"""
check_windspeed(df_wind, guidelines, level, lb_wind, ub_wind, lb_sail, ub_sail)

    Evaluates the forecast windspeed against general guidelines for windspeed, sail size and skill level.
    Provides a recommendation wether one should wait for better conditions, change sail size or go windsurfing.

        Arguments:
            df_wind: The DataFrame containing the wind forecast.
            guidelines: The DataFrame containing the wind speed guidelines for the different skill levels.
            level: The given skill level (valid levels are "beginner", "intermediate", or "advanced").
            lb_wind and ub_wind: The bounds of the recommended wind speed range.
            lb_sail and ub_sail: The bounds of the recommended sail size range.

        Returns:
            A vector containing the recommendation for each time point as a string.
"""
function check_windspeed(df_wind, guidelines, level, lb_wind, ub_wind, lb_sail, ub_sail)

    results_windspeed = String[]

    for i in 1:size(df_wind, 1)
        if df_wind."windspeed_10m"[i] < 4
            push!(results_windspeed, "Wind is too low for windsurfing, consider waiting for better conditions.")
        elseif df_wind."windspeed_10m"[i] >= 28
            push!(results_windspeed, "Wind is too strong for windsurfing, consider waiting for better conditions.")
        elseif 4 <= df_wind."windspeed_10m"[i] < lb_wind
            push!(results_windspeed, "Wind is too low for your sail size, consider using a bigger sail of 
            up to $(ub_sail) m² and check again.")
        elseif ub_wind <= df_wind."windspeed_10m"[i] < 28
            push!(results_windspeed, "Wind is too strong for your sail size, consider using a smaller sail of 
            at least $(lb_sail) m² and check again.")
        else
            current = check_level(guidelines, df_wind, level, i)
            if current == "too low for your skill level" || current == "too strong for your skill level"
                push!(results_windspeed, "Wind is $(current), consider waiting for better conditions.")
            else
                push!(results_windspeed, "Wind is $(current) for windsurfing.")
            end
        end
    end

    return results_windspeed

end

"""
check_forecast(bodyweight, sail_size, level, city, coast)

    Loads the wind forecast and evaluates the conditions based on the users bodyweight, sail size, skill level,
    and coast direction. Combines the results of the recommendations based on windspeed, gusts and wind direction
    into a DataFrame.
    df_wind can be set by collecting real forecast data or test data from a CSV.

    Arguments:
        bodyweight: given bodyweight in kg.
        sail_size: given sail size in m².
        coast:  The direction in degrees in which the coast is facing (pointing towards the sea).
                Must be between 0 and 359.99... degrees.
        level: The given skill level (valid levels are "beginner", "intermediate", or "advanced").

    Returns:
        A DataFrame containing all the recommendations per forecast time.
"""
function check_forecast(bodyweight, sail_size, level, city, coast; wind_data = collect_wind_data(city))

    guidelines, lb_wind, ub_wind, lb_sail, ub_sail = check_bodyweight(bodyweight, sail_size)

    df_results = DataFrame()
    df_results[!, :TIME] = df_wind.TIME
    df_results[!, :Windspeed] = df_wind.windspeed_10m

    if !(level in ["beginner", "intermediate", "advanced"])
        error("Please enter a valid skill level: beginner, intermediate, or advanced")
    end

    results_direction = check_direction(df_wind, coast, level)
    results_gusts = check_gusts(df_wind, level)
    results_windspeed = check_windspeed(df_wind, guidelines, level, lb_wind, ub_wind, lb_sail, ub_sail)

    df_results[!, "windspeed_recs"] = results_windspeed
    df_results[!, "direction_recs"] = results_direction
    df_results[!, "gusts"] = results_gusts

    return df_results

end

"""
get_recs(bodyweight, sail_size, level, city, coast)

    Generates an overall recommendation by selecting the most relevant criteria first. If none of the
    criteria apply, it returns the windspeed based recommendation.

    Arguments:
        bodyweight: given bodyweight in kg.
        sail_size: given sail size in m².
        coast:  The direction in degrees in which the coast is facing (pointing towards the sea).
                Must be between 0 and 359.99... degrees.
        level: The given skill level (valid levels are "beginner", "intermediate", or "advanced").

    Returns:
        A DataFrame containing the forecast time and the overall recommendations.
"""
function get_recs(bodyweight, sail_size, level, city, coast; wind_data = collect_wind_data(city))

    df_results = check_forecast(bodyweight, sail_size, level, city,  coast; wind_data)
    df_recs = DataFrame()
    df_recs[!, :Time] = df_results.TIME
    rec = String[]
    
    for i in 1:size(df_results, 1)
        if occursin("too strong", df_results."windspeed_recs"[i]) ||
            occursin("too low", df_results."windspeed_recs"[i])
            push!(rec, df_results."windspeed_recs"[i])
        elseif occursin("Offshore", df_results."direction_recs"[i])
            push!(rec, df_results."direction_recs"[i])
        elseif occursin("too strong for your skill level", df_results."gusts"[i])
            push!(rec, df_results."gusts"[i])
        else
            push!(rec, df_results."windspeed_recs"[i])
        end
    end

    df_recs[!, :Recommendation] = rec

    return df_recs

end