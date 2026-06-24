using SRJBackend.Application.Interfaces;

namespace SRJBackend.Infrastructure.Services;

/// <summary>
/// A controllable clock for development/testing. The time-simulator console advances
/// it (e.g. one month at a time) and runs debt generation each step, so the monthly
/// tuition behaviour can be exercised without waiting for real month boundaries.
/// </summary>
public class VirtualClock : IClock
{
    private DateTime _now;

    public VirtualClock(DateTime? start = null)
    {
        _now = start ?? DateTime.UtcNow;
    }

    public DateOnly Today => DateOnly.FromDateTime(_now);
    public DateTime UtcNow => _now;

    public void Set(DateOnly date) => _now = date.ToDateTime(TimeOnly.MinValue);
    public void AdvanceDays(int days) => _now = _now.AddDays(days);
    public void AdvanceMonths(int months) => _now = _now.AddMonths(months);
}
