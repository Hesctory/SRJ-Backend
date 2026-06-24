namespace SRJBackend.Application.Interfaces;

/// <summary>
/// Abstracts the current time so time-dependent logic (debt status, the monthly
/// tuition scheduler) can run against real time in production or a controllable
/// virtual clock during development/testing.
/// </summary>
public interface IClock
{
    DateOnly Today { get; }
    DateTime UtcNow { get; }
}
