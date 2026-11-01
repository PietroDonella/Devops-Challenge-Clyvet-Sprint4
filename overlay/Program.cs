using ClyvoVet.Api;
using ClyvoVet.Infrastructure.Context;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using ClyvoVet.Api.HealthChecks;
using Serilog;
using OpenTelemetry.Metrics;
using OpenTelemetry.Trace;

Log.Logger = new LoggerConfiguration()
    .MinimumLevel.Information() 
    .MinimumLevel.Override("Microsoft", Serilog.Events.LogEventLevel.Warning) 
    .MinimumLevel.Override("Microsoft.Hosting.Lifetime", Serilog.Events.LogEventLevel.Information) 
    .Enrich.FromLogContext() 
    .WriteTo.Console() 
    .WriteTo.File("logs/clyvovet-.txt", rollingInterval: RollingInterval.Day) 
    .CreateLogger();

try
{
    Log.Information("Iniciando a API ClyvoVet...");

    var builder = WebApplication.CreateBuilder(args);

    builder.Host.UseSerilog();

    builder.Services.AddDbContext<ClyvoVetContext>(options =>
        options.UseOracle(
            builder.Configuration.GetConnectionString("OracleConnection"),
            oracleOptions => oracleOptions.UseOracleSQLCompatibility(OracleSQLCompatibility.DatabaseVersion19)
        ));

    builder.Services.AddOpenTelemetry()
        .WithTracing(tracing => tracing
            .AddAspNetCoreInstrumentation() 
            .AddHttpClientInstrumentation() 
            .AddConsoleExporter())          
        .WithMetrics(metrics => metrics
            .AddAspNetCoreInstrumentation() 
            .AddConsoleExporter());         

    builder.Services.AddHealthChecks()
        .AddOracle(builder.Configuration.GetConnectionString("OracleConnection"), name: "Database_Oracle")
        .AddUrlGroup(new Uri("https://www.fiap.com.br"), name: "FIAP")
        .AddUrlGroup(new Uri("https://www.google.com"), name: "GOOGLE");

    builder.Services.AddControllers();

    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddSwaggerGen(options =>
    {
        options.EnableAnnotations();
        options.SwaggerDoc("v1", new Microsoft.OpenApi.OpenApiInfo
        {
            Title = AppInfo.Titulo,
            Version = "v1"
        });
    });

    var app = builder.Build();

    app.UseSerilogRequestLogging(); 

    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.DocumentTitle = AppInfo.Titulo;
    });

    app.UseHttpsRedirection();

    app.MapGet("/", () => Results.Content(
        $"""
        <!DOCTYPE html>
        <html lang="pt-BR">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <title>{AppInfo.Titulo}</title>
        </head>
        <body style="font-family:Segoe UI,Arial,sans-serif;margin:48px;color:#163A54">
          <h1>{AppInfo.Titulo}</h1>
          <p>API da clínica veterinária Clyvo Vet. Tutores, pets, consultas e prontuários.</p>
          <p><a href="/swagger">Abrir o Swagger</a></p>
        </body>
        </html>
        """,
        "text/html; charset=utf-8"));

    app.MapControllers();

    app.MapHealthChecks("/health", new HealthCheckOptions
    {
        ResponseWriter = HealthCheckResponseWriter.WriteJsonResponse
    });

    app.Run();
}
catch (Exception ex)
{
    Log.Fatal(ex, "Erro fatal ao iniciar a API.");
}
finally
{
    Log.CloseAndFlush();
}
public partial class Program { }