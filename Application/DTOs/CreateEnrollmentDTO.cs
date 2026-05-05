namespace SRJBackend.Application.DTOs;

public class CreateEnrollmentDTO
{
    public int SchoolYearId { get; set; }
    public int GradeOfferingId { get; set; }
    public int SectionId { get; set; }
}

public class EnrollStudentDTO
{
    public CreateStudentDTO Student { get; set; } = null!;
    public CreateEnrollmentDTO Enrollment { get; set; } = null!;
}

public class EnrollResultDTO
{
    public int StudentId { get; set; }
    public int EnrollmentId { get; set; }
}

public class ReenrollResultDTO
{
    public int EnrollmentId { get; set; }
}

public class EligibleSchoolYearDTO
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public bool GradeOfferingsAvailable { get; set; }
}

public class ErrorDTO
{
    public string Code { get; set; } = null!;
    public string Message { get; set; } = null!;
}