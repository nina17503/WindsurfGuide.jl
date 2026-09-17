using Test
using WindsurfGuide
using DataFrames
using CSV

@testset "windsurfing recommendations" begin
    @testset "sail recommendations" begin
        guidelines1, lb_wind1, ub_wind1, lb_sail1, ub_sail1 = WindsurfGuide.check_bodyweight(72, 5)
        guidelines2, lb_wind2, ub_wind2, lb_sail2, ub_sail2 = WindsurfGuide.check_bodyweight(75, 5)

        @test [lb_wind1, ub_wind1, lb_sail1, ub_sail1] == [4, 19, 4, 5.5]
        @test [lb_wind2, ub_wind2, lb_sail2, ub_sail2] == [13, 28, 4.5, 6]
    end

    @testset "wind direction" begin
        result = WindsurfGuide.directions(270)

        @test result."dir"[2] == "crossshore"
        @test result."start"[4] == 247.5
        @test result."stop"[6] == 202.5
        @test_throws ErrorException WindsurfGuide.directions(360)
        @test_throws ErrorException WindsurfGuide.directions(-1)

        df_test1 = DataFrame(
            wind_direction_10m = [0, 90, 180, 270])
        df_test2 = DataFrame(
            wind_direction_10m = [337.5, 337.4, 337.6])

        result1 = WindsurfGuide.check_direction(df_test1, 270, "beginner")
        result2 = WindsurfGuide.check_direction(df_test2, 270, "beginner")

        @test result1[1] == "Crossshore wind, very good for all levels."
        @test result1[2] == "Offshore wind, consider waiting for better conditions."
        @test result1[3] == "Crossshore wind, very good for all levels."
        @test result1[4] == "Onshore wind, very good for your skill level."
        @test result2[1] == "Crossshore wind, very good for all levels."
        @test result2[2] == "Cross-onshore wind, very good for all levels."
        @test result2[3] == "Crossshore wind, very good for all levels."
    end

    @testset "wind conditions" begin
        df_test = DataFrame(
            windspeed_10m = [10, 10, 10],
            wind_gusts_10m = [17, 18, 19])

        result = WindsurfGuide.check_gusts(df_test, "beginner")

        @test occursin("stable", result[1])
        @test occursin("too strong", result[2])
        @test occursin("too strong", result[3])

        guidelines = CSV.read(joinpath(@__DIR__, "..", "data", "guidelines.csv"), DataFrame, missingstring = "missing")
        lb_wind = 5
        ub_wind = 19
        lb_sail = 4.0
        ub_sail = 5.5
        
        df_tests = DataFrame(
            windspeed_10m = [2, 4, 5, 9, 14, 18, 19, 28])

        results = WindsurfGuide.check_windspeed(df_tests, guidelines, "intermediate", lb_wind, ub_wind, lb_sail, ub_sail)

        @test occursin("too low for windsurfing", results[1])
        @test occursin("too low for your sail size", results[2])
        @test occursin("too low for your skill level", results[3])
        @test occursin("is good", results[4])
        @test occursin("very good", results[5])
        @test occursin("good for improvement", results[6])
        @test occursin("too strong for your sail size", results[7])
        @test occursin("too strong for windsurfing", results[8])
    end

    @testset "final recommendations" begin
        wind_data = CSV.read(joinpath(WindsurfGuide.data_dir, "test_wind_data.csv"), DataFrame)
        df_test = WindsurfGuide.get_recs(72, 5, "intermediate", 270; wind_data)

        @test occursin("very good", df_test."Recommendation"[53])
        @test occursin("gusts are too strong", df_test."Recommendation"[52])
        @test occursin("Offshore", df_test."Recommendation"[78])
        @test occursin("too low for your skill level", df_test."Recommendation"[66])
        @test occursin("too strong for your sail size", df_test."Recommendation"[144])
    end
end