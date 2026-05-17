using SRJBackend.Domain.Exceptions;

namespace SRJBackend.Domain.Entities;

public class DSchoolYear
{
    public int Id { get; private set; }
    public short Year { get; private set; }
    public DateOnly StartDate { get; private set; }
    public DateOnly? EndDate { get; private set; }
    public bool IsActive { get; private set; }

    public static DSchoolYear Create(int id, short year, DateOnly startDate, DateOnly? endDate, bool isActive)
    {
        if (year <= 0)
            throw new ArgumentException("El año escolar es inválido.", nameof(year));
        if (startDate == default)
            throw new ArgumentException("La fecha de inicio es requerida.", nameof(startDate));
        if (endDate.HasValue && endDate.Value <= startDate)
            throw new DomainException("La fecha de fin debe ser posterior a la fecha de inicio.");

        return new DSchoolYear(id, year, startDate, endDate, isActive);
    }

    internal static DSchoolYear Reconstitute(int id, short year, DateOnly startDate, DateOnly? endDate, bool isActive)
        => new DSchoolYear(id, year, startDate, endDate, isActive);

    private DSchoolYear(int id, short year, DateOnly startDate, DateOnly? endDate, bool isActive)
    {
        Id = id;
        Year = year;
        StartDate = startDate;
        EndDate = endDate;
        IsActive = isActive;
    }
}
