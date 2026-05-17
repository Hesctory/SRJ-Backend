using SRJBackend.Application.DTOs;
using SRJBackend.Domain.Entities;

namespace SRJBackend.Application.Mappers;

public static class EnrollmentMapper
{
    public static EnrollmentDTO ToDTO(DEnrollment enrollment) => new EnrollmentDTO
    {
        Id = enrollment.Id,
        Code = enrollment.Code.Code,
        CodeNumber = enrollment.Code.CodeNumber,
        StudentId = enrollment.StudentId,
        LevelId = enrollment.Placement.LevelId,
        GradeId = enrollment.Placement.GradeId,
        ShiftId = enrollment.Placement.ShiftId,
        SectionId = enrollment.Placement.SectionId,
        SchoolFeeConceptId = enrollment.SchoolFeeConceptId,
        SchoolYearId = enrollment.SchoolYearId,
        PreviousSchool = enrollment.PreviousSchool
    };
}
