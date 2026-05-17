namespace SRJBackend.Domain.ValueObjects;

public record AcademicPlacement
{
    public int LevelId { get; }
    public int GradeId { get; }
    public int ShiftId { get; }
    public int SectionId { get; }

    public AcademicPlacement(int levelId, int gradeId, int shiftId, int sectionId)
    {
        if (levelId <= 0)
            throw new ArgumentException("El nivel educativo es requerido.", nameof(levelId));
        if (gradeId <= 0)
            throw new ArgumentException("El grado es requerido.", nameof(gradeId));
        if (shiftId <= 0)
            throw new ArgumentException("El turno es requerido.", nameof(shiftId));
        if (sectionId <= 0)
            throw new ArgumentException("La sección es requerida.", nameof(sectionId));

        LevelId = levelId;
        GradeId = gradeId;
        ShiftId = shiftId;
        SectionId = sectionId;
    }
}
