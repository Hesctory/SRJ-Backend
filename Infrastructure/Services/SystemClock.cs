using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Services;

/// <summary>Real wall-clock implementation of <see cref="IClock"/>. Used in production.</summary>
public class SystemClock : IClock
{
    public DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);
    public DateTime UtcNow => DateTime.UtcNow;
}
